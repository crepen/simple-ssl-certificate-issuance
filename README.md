# SSL Certificate Issuance Tool

Issues SSL certificates from ZeroSSL using DNS TXT challenge.
Works on Linux and Docker environments with no pre-installation required.

[한국어](README.ko.md)

## Quick Start

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

> `| sh` piping does not work because the script requires interactive input.

## How to Get a Certificate

1. **Menu 1** — Enter your email and the folder where certificates will be saved
2. **Menu 2** — Enter your domain and copy the TXT record shown
3. Add the TXT record to your DNS and wait a few minutes for propagation
4. **Menu 3** — Enter the same domain to verify and issue the certificate

Certificate files are saved to `<your folder>/<domain>/`:

| File | Description |
|------|-------------|
| `cert.pem` | Certificate |
| `key.pem` | Private key |
| `fullchain.pem` | Full chain |
| `ca.pem` | CA certificate |

## Non-Interactive Mode

```sh
sh /tmp/ssl_cert.sh config user@example.com /etc/ssl/certs
sh /tmp/ssl_cert.sh issue example.com
# → Add the displayed TXT record to DNS, then:
sh /tmp/ssl_cert.sh verify example.com
```

Other commands:

```sh
sh /tmp/ssl_cert.sh show              # Show current settings
sh /tmp/ssl_cert.sh delete example.com  # Delete saved certificate
sh /tmp/ssl_cert.sh help              # Show usage
```

## Wildcard Domains

Use `*.example.com` to issue a certificate covering both `*.example.com` and `example.com`.

```sh
sh /tmp/ssl_cert.sh issue '*.example.com'
sh /tmp/ssl_cert.sh verify '*.example.com'
```

## Troubleshooting

**TXT record not verified**
DNS propagation may still be in progress. Wait a few minutes and retry menu 3.

**`retryafter=86400` error**
ZeroSSL is rate-limiting due to repeated failed attempts. Re-run menu 2 to get a new TXT record, update DNS, then retry menu 3. Or wait a few hours before retrying.
