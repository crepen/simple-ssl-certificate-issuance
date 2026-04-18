#!/bin/sh

set -eu

VERSION="1.0.1"
CONFIG_FILE="${HOME}/.ssl_cert_config"
ACME_HOME="${HOME}/.acme.sh"
ACME_BIN="${ACME_HOME}/acme.sh"
ACME_SERVER="zerossl"
DOMAIN=""

# --- colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_section() { printf "\n${CYAN}=== %s ===${NC}\n" "$*"; }

# --- config file -------------------------------------------------------------
load_config() {
    EMAIL=""
    CERT_DIR=""
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        . "$CONFIG_FILE"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
EMAIL="${EMAIL}"
CERT_DIR="${CERT_DIR}"
EOF
    chmod 600 "$CONFIG_FILE"
    mkdir -p "$CERT_DIR"
    log_info "Configuration saved: $CONFIG_FILE"
}

# --- settings management -----------------------------------------------------
configure_settings() {
    log_section "Settings"

    current_email="${EMAIL:-not set}"
    current_dir="${CERT_DIR:-not set}"

    printf "Current settings:\n"
    printf "  Email            : %s\n" "$current_email"
    printf "  Certificate path : %s\n" "$current_dir"
    printf "\n"

    printf "Email address [%s]: " "$current_email"
    read -r input_email
    [ -n "$input_email" ] && EMAIL="$input_email"

    printf "Certificate base path [%s]: " "$current_dir"
    read -r input_dir
    [ -n "$input_dir" ] && CERT_DIR="$input_dir"

    if [ -z "$EMAIL" ] || [ -z "$CERT_DIR" ]; then
        log_error "Email and certificate path are required."
        return 1
    fi

    save_config
}

# --- ensure curl or wget is available, install if missing --------------------
ensure_downloader() {
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return 0
    fi

    log_warn "Neither curl nor wget found. Attempting to install curl..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq curl
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl
    elif command -v zypper >/dev/null 2>&1; then
        zypper install -y curl
    else
        log_error "No supported package manager found (apt-get, apk, yum, dnf, zypper)."
        log_error "Please install curl or wget manually."
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_error "curl installation failed."
        return 1
    fi

    log_info "curl installed successfully."
}

# --- acme.sh install check ---------------------------------------------------
check_install_acme() {
    log_section "acme.sh Check"

    if [ -f "$ACME_BIN" ]; then
        ver=$("$ACME_BIN" --version 2>/dev/null | head -1 || echo "unknown")
        log_info "acme.sh already installed: $ver"
        return 0
    fi

    log_warn "acme.sh not found. Starting installation..."

    ensure_downloader || return 1

    downloader=""
    if command -v curl >/dev/null 2>&1; then
        downloader="curl"
    elif command -v wget >/dev/null 2>&1; then
        downloader="wget"
    fi

    install_dir=$(mktemp -d /tmp/acme_install.XXXXXX)
    install_script="${install_dir}/acme.sh"

    log_info "Downloading acme.sh..."
    if [ "$downloader" = "curl" ]; then
        curl -fsSL https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh \
            -o "$install_script"
    else
        wget -qO "$install_script" \
            https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
    fi

    chmod +x "$install_script"

    # --install: self-install to ACME_HOME, --no-cron: skip cron setup (for Docker environments)
    log_info "Installing acme.sh (no-cron)..."
    sh "$install_script" \
        --install \
        --home "$ACME_HOME" \
        --no-cron \
        --email "${EMAIL}" \
        2>&1

    rm -rf "$install_dir"

    if [ ! -f "$ACME_BIN" ]; then
        log_error "acme.sh installation failed."
        return 1
    fi

    log_info "acme.sh installed successfully."

    log_info "Registering ZeroSSL account..."
    "$ACME_BIN" --register-account -m "${EMAIL}" --server "$ACME_SERVER" 2>&1
}

# --- config validation -------------------------------------------------------
require_config() {
    load_config
    if [ -z "$EMAIL" ] || [ -z "$CERT_DIR" ]; then
        log_error "Configuration required. Run menu [1] Settings first."
        return 1
    fi
}

# --- domain input and path resolution ----------------------------------------
input_domain() {
    if [ -z "$DOMAIN" ]; then
        printf "Domain (e.g. example.com or *.example.com): "
        read -r DOMAIN
    fi
    if [ -z "$DOMAIN" ]; then
        log_error "Domain is required."
        return 1
    fi

    # Replace * with 'wildcard' for use as a directory name
    domain_safe=$(printf '%s' "$DOMAIN" | sed 's/\*/wildcard/g')
    DOMAIN_DIR="${CERT_DIR}/${domain_safe}"
}

# --- build domain flags for acme.sh ------------------------------------------
build_domain_flag() {
    case "$DOMAIN" in
        \*.*)
            base_domain="${DOMAIN#\*.}"
            printf -- '-d %s -d %s' "$DOMAIN" "$base_domain"
            ;;
        *)
            printf -- '-d %s' "$DOMAIN"
            ;;
    esac
}

# --- ensure ZeroSSL account is registered ------------------------------------
ensure_zerossl_account() {
    log_info "Ensuring ZeroSSL account is registered..."
    "$ACME_BIN" --register-account -m "${EMAIL}" --server "$ACME_SERVER" 2>&1 || true
}

# --- issue TXT challenge string ----------------------------------------------
issue_txt_challenge() {
    log_section "Issue TXT Challenge"

    require_config || return 1
    input_domain || return 1
    check_install_acme || return 1
    ensure_zerossl_account

    mkdir -p "$DOMAIN_DIR"

    # Remove stale acme.sh domain state to ensure Le_OrderFinalize and all
    # order fields are freshly populated by a clean --issue run
    for _suffix in "_ecc" ""; do
        _state="${ACME_HOME}/${DOMAIN}${_suffix}"
        if [ -d "$_state" ]; then
            log_info "Removing stale domain state: $_state"
            rm -rf "$_state"
        fi
    done

    log_info "Domain: $DOMAIN"
    log_info "Requesting DNS TXT challenge from ZeroSSL..."
    printf "\n"

    acme_log="${ACME_HOME}/acme.sh.log"
    : > "$acme_log"

    # --force: always create a fresh ACME order so the TXT value is always new
    # dns_manual: built-in acme.sh provider for manual TXT DNS validation
    # shellcheck disable=SC2046
    "$ACME_BIN" \
        --issue \
        --dns dns_manual \
        $(build_domain_flag) \
        --server "$ACME_SERVER" \
        --force \
        --log "$acme_log" \
        2>&1 || true

    # Extract and display TXT record
    printf "\n"
    if [ -f "$acme_log" ]; then
        txt_section=$(grep -A 3 -E "(Add the following TXT|_acme-challenge|TXT value)" "$acme_log" 2>/dev/null || true)
        if [ -n "$txt_section" ]; then
            log_info "--- TXT record to add to your DNS ---"
            printf "%s\n" "$txt_section"
            log_info "-------------------------------------"
        else
            log_warn "TXT record not found. Showing full acme.sh log:"
            cat "$acme_log"
        fi
    fi

    printf "\n"
    log_warn "Add the TXT record above to your DNS, then run menu [3]."
    log_warn "DNS propagation may take several minutes."
}

# --- verify TXT and complete certificate issuance ----------------------------
verify_and_issue() {
    log_section "Verify TXT and Issue Certificate"

    require_config || return 1
    input_domain || return 1

    if [ ! -f "$ACME_BIN" ]; then
        log_error "acme.sh is not installed. Run menu [2] first."
        return 1
    fi

    log_info "Verifying DNS TXT record and issuing certificate..."
    printf "\n"

    renew_out=$(mktemp /tmp/acme_renew.XXXXXX)

    # shellcheck disable=SC2046
    "$ACME_BIN" \
        --renew \
        $(build_domain_flag) \
        > "$renew_out" 2>&1 || true
    cat "$renew_out"

    if grep -q "retryafter=86400" "$renew_out" 2>/dev/null; then
        printf "\n"
        log_error "ZeroSSL returned retry-after=86400 (24 hours)."
        log_warn "This is caused by previous failed verification attempts caching a negative DNS result."
        log_warn "Options:"
        log_warn "  1. Wait a few hours, then retry menu [3]"
        log_warn "  2. Run menu [2] again to generate a NEW TXT challenge, update DNS, then retry menu [3]"
        rm -f "$renew_out"
        return 1
    fi

    if grep -qE "(Error|error|failed)" "$renew_out" 2>/dev/null && \
       ! grep -q "Cert success" "$renew_out" 2>/dev/null; then
        rm -f "$renew_out"
        log_error "Certificate renewal failed. Check the output above for details."
        return 1
    fi

    rm -f "$renew_out"
    printf "\n"

    mkdir -p "$DOMAIN_DIR"

    log_info "Installing certificate to ${DOMAIN_DIR}..."
    "$ACME_BIN" \
        --install-cert \
        -d "${DOMAIN}" \
        --cert-file      "${DOMAIN_DIR}/cert.pem" \
        --key-file       "${DOMAIN_DIR}/key.pem" \
        --fullchain-file "${DOMAIN_DIR}/fullchain.pem" \
        --ca-file        "${DOMAIN_DIR}/ca.pem" \
        2>&1

    printf "\n"
    log_info "Certificate issued successfully!"
    log_info "Files:"
    log_info "  Certificate : ${DOMAIN_DIR}/cert.pem"
    log_info "  Private key : ${DOMAIN_DIR}/key.pem"
    log_info "  Full chain  : ${DOMAIN_DIR}/fullchain.pem"
    log_info "  CA cert     : ${DOMAIN_DIR}/ca.pem"
}

# --- delete saved certificate ------------------------------------------------
delete_cert() {
    log_section "Delete Saved Certificate"

    require_config || return 1

    if [ ! -d "$CERT_DIR" ]; then
        log_error "Certificate directory not found: $CERT_DIR"
        return 1
    fi

    # Non-interactive: domain provided as argument
    if [ -n "$DOMAIN" ]; then
        domain_safe=$(printf '%s' "$DOMAIN" | sed 's/\*/wildcard/g')
        target_dir="${CERT_DIR}/${domain_safe}"
        if [ ! -d "$target_dir" ]; then
            log_error "Certificate not found: $target_dir"
            return 1
        fi
        rm -rf "$target_dir"
        log_info "Deleted: $target_dir"
        return 0
    fi

    # Collect subdirectories (each represents a domain)
    i=0
    for d in "$CERT_DIR"/*/; do
        [ -d "$d" ] || continue
        i=$((i + 1))
        eval "domain_list_${i}=$(basename "$d")"
    done

    if [ "$i" -eq 0 ]; then
        log_warn "No saved certificates found in: $CERT_DIR"
        return 0
    fi

    printf "Saved certificates:\n"
    j=1
    while [ "$j" -le "$i" ]; do
        eval "_name=\$domain_list_${j}"
        printf "  %d. %s\n" "$j" "$_name"
        j=$((j + 1))
    done
    printf "  0. Cancel\n"
    printf "\nSelect domain to delete: "
    read -r sel

    case "$sel" in
        0) log_info "Cancelled."; return 0 ;;
        *) ;;
    esac

    if ! printf '%s' "$sel" | grep -qE '^[0-9]+$' || \
       [ "$sel" -lt 1 ] || [ "$sel" -gt "$i" ]; then
        log_error "Invalid selection."
        return 1
    fi

    eval "_target=\$domain_list_${sel}"
    target_dir="${CERT_DIR}/${_target}"

    printf "\n"
    log_warn "This will permanently delete: ${target_dir}"
    printf "Are you sure? [y/N]: "
    read -r confirm

    case "$confirm" in
        y|Y)
            rm -rf "$target_dir"
            log_info "Deleted: ${target_dir}"
            ;;
        *)
            log_info "Cancelled."
            ;;
    esac
}

# --- show current settings ---------------------------------------------------
show_config() {
    log_section "Current Settings"
    load_config
    printf "  Email            : %s\n" "${EMAIL:-not set}"
    printf "  Certificate path : %s\n" "${CERT_DIR:-not set}"
    if [ -f "$ACME_BIN" ]; then
        printf "  acme.sh          : installed\n"
    else
        printf "  acme.sh          : not installed\n"
    fi
}

# --- main menu ---------------------------------------------------------------
main_menu() {
    while true; do
        printf "\n"
        printf "============================================\n"
        printf "  SSL Certificate Tool (ZeroSSL / TXT mode)\n"
        printf "  version %s\n" "$VERSION"
        printf "============================================\n"
        printf "  1. Settings (email, certificate path)\n"
        printf "  2. Issue TXT challenge string\n"
        printf "  3. Verify TXT and complete issuance\n"
        printf "  4. Show current settings\n"
        printf "  5. Delete saved certificate\n"
        printf "  0. Exit\n"
        printf "============================================\n"
        printf "Select: "
        read -r choice

        case "$choice" in
            1) configure_settings ;;
            2) issue_txt_challenge ;;
            3) verify_and_issue ;;
            4) show_config ;;
            5) delete_cert ;;
            0)
                log_info "Exiting."
                exit 0
                ;;
            *)
                log_warn "Invalid selection. Enter 0-5."
                ;;
        esac
    done
}

# --- non-interactive usage help ----------------------------------------------
usage() {
    printf "SSL Certificate Tool (ZeroSSL / TXT mode) v%s\n" "$VERSION"
    printf "Usage: %s [command] [args]\n" "$0"
    printf "\n"
    printf "Commands:\n"
    printf "  (no args)              Interactive menu\n"
    printf "  config <email> <path>  Save email and certificate base path\n"
    printf "  issue  <domain>        Issue TXT challenge string\n"
    printf "  verify <domain>        Verify TXT and issue certificate\n"
    printf "  delete <domain>        Delete saved certificate\n"
    printf "  show                   Show current settings\n"
    printf "\n"
    printf "Examples:\n"
    printf "  %s config user@example.com /etc/ssl/certs\n" "$0"
    printf "  %s issue example.com\n" "$0"
    printf "  %s issue '*.example.com'\n" "$0"
    printf "  %s verify example.com\n" "$0"
    printf "  %s delete example.com\n" "$0"
}

# --- entry point -------------------------------------------------------------
load_config

if [ $# -eq 0 ]; then
    main_menu
else
    case "$1" in
        config)
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 config <email> <cert_dir>"
                exit 1
            fi
            EMAIL="$2"
            CERT_DIR="$3"
            save_config
            ;;
        issue)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 issue <domain>"
                exit 1
            fi
            DOMAIN="$2"
            issue_txt_challenge
            ;;
        verify)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 verify <domain>"
                exit 1
            fi
            DOMAIN="$2"
            verify_and_issue
            ;;
        delete)
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 delete <domain>"
                exit 1
            fi
            DOMAIN="$2"
            delete_cert
            ;;
        show)
            show_config
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
fi
