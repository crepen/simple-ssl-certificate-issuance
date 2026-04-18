# SSL Certificate Issuance Tool

A shell script for issuing SSL certificates from ZeroSSL using DNS TXT challenge via acme.sh.
Works on Linux and Docker container environments without any additional package installation.

[한국어](README.ko.md)

## Features

- POSIX sh compatible (no bash required, works with dash)
- Automatically installs `curl` / `wget` via package manager if missing
- Automatically installs acme.sh (force install, no cron)
- Automatically registers ZeroSSL account
- Wildcard domain support (`*.example.com`)
- TXT challenge issuance and certificate issuance run as separate steps
- Certificates saved in per-domain subdirectories

## Requirements

- `sh` (POSIX-compatible shell)
- `curl` or `wget` — automatically installed if missing, provided one of the following package managers is available

| Package Manager | Target Distribution |
|----------------|---------------------|
| `apt-get` | Debian / Ubuntu |
| `apk` | Alpine Linux |
| `yum` | CentOS / RHEL (legacy) |
| `dnf` | Fedora / RHEL 8+ |
| `zypper` | openSUSE |

## Usage

### Run from local file

```sh
sh ssl_cert.sh
```

### Run directly without saving (curl)

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

### Run directly without saving (wget)

```sh
wget -qO /tmp/ssl_cert.sh https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

> The script uses interactive input, so piping (`| sh`) will not work.
> Download to a temporary file first and run it as shown above.

### Non-interactive (pass arguments directly)

You can skip the menu by passing a command and arguments directly.

```sh
# Save settings
sh ssl_cert.sh config user@example.com /etc/ssl/certs

# Issue TXT challenge
sh ssl_cert.sh issue example.com
sh ssl_cert.sh issue '*.example.com'

# Verify TXT and issue certificate
sh ssl_cert.sh verify example.com

# Delete saved certificate
sh ssl_cert.sh delete example.com

# Show current settings
sh ssl_cert.sh show
```

Download and run non-interactively with curl:

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh
sh /tmp/ssl_cert.sh config user@example.com /etc/ssl/certs
sh /tmp/ssl_cert.sh issue example.com
sh /tmp/ssl_cert.sh verify example.com
```

---

### Interactive menu

Running without arguments displays the menu.

```
============================================
  SSL Certificate Tool (ZeroSSL / TXT mode)
============================================
  1. Settings (email, certificate path)
  2. Issue TXT challenge string
  3. Verify TXT and complete issuance
  4. Show current settings
  5. Delete saved certificate
  0. Exit
============================================
```

## Menu Description

### 1. Settings (email, certificate path)

Enter the email address for your ZeroSSL account and the base path where certificates will be stored.
Settings are saved to `~/.ssl_cert_config` and loaded automatically on subsequent runs.

### 2. Issue TXT challenge string

Enter a domain to receive a DNS TXT record value from ZeroSSL.

1. Enter domain (e.g. `example.com` or `*.example.com`)
2. Check for acme.sh installation and install if missing
3. Output TXT record value

Add the displayed TXT record to your DNS, then run menu 3.

> Always removes any previous challenge state and creates a fresh order.
> If ZeroSSL reuses a cached DNS validation and issues the certificate immediately, the state is cleared and a new TXT challenge is generated automatically.

### 3. Verify TXT and issue certificate

Run after adding the TXT record to your DNS.

1. Enter domain (same as entered in menu 2)
2. ZeroSSL verifies the TXT record
3. Certificate issued and saved

Issued files are saved under `<certificate path>/<domain>/`.

| File | Description |
|------|-------------|
| `cert.pem` | Certificate |
| `key.pem` | Private key |
| `fullchain.pem` | Full chain certificate |
| `ca.pem` | CA certificate |

### 4. Show current settings

Displays the saved email, certificate path, and acme.sh installation status.

### 5. Delete saved certificate

Lists saved domain certificates by number and deletes the selected domain's certificate files.

## Issuance Flow

```
[Menu 1] Set email and certificate base path
    ↓
[Menu 2] Enter domain → Receive TXT record value
    ↓
Add TXT record to DNS (manual)
    ↓
Wait for DNS propagation (a few minutes)
    ↓
[Menu 3] Enter domain → Verify TXT → Issue and save certificate
```

## Wildcard Domains

Entering `*.example.com` issues a certificate covering both `*.example.com` and `example.com`.
The certificate is saved under `<base path>/wildcard.example.com/`.

## Configuration File Locations

| Path | Contents |
|------|----------|
| `~/.ssl_cert_config` | Email and certificate base path |
| `~/.acme.sh/` | acme.sh installation directory |

## Troubleshooting

### `retryafter=86400` error

ZeroSSL has cached a previous failed verification attempt and is refusing retries for 24 hours.

- Re-run menu 2 to generate a new TXT challenge, update DNS, then retry menu 3.
- Alternatively, wait a few hours and retry menu 3.
