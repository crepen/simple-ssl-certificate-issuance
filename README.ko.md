# SSL 인증서 발급 도구

ZeroSSL에서 DNS TXT 방식으로 SSL 인증서를 발급하는 도구입니다.
Linux 및 Docker 환경에서 별도 설치 없이 바로 사용할 수 있습니다.

[English](README.md)

## 빠른 시작

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

> 대화형 입력이 필요하므로 `| sh` 방식은 동작하지 않습니다.

## 인증서 발급 방법

1. **메뉴 1** — 이메일과 인증서를 저장할 폴더를 입력합니다
2. **메뉴 2** — 도메인을 입력하고 표시된 TXT 레코드를 복사합니다
3. DNS에 TXT 레코드를 등록하고 수 분 기다립니다
4. **메뉴 3** — 동일한 도메인을 입력하여 검증 후 인증서를 발급받습니다

인증서 파일은 `<설정한 폴더>/<도메인>/`에 저장됩니다:

| 파일 | 설명 |
|------|------|
| `cert.pem` | 인증서 |
| `key.pem` | 개인 키 |
| `fullchain.pem` | 풀체인 인증서 |
| `ca.pem` | CA 인증서 |

## 비대화형 모드

```sh
sh /tmp/ssl_cert.sh config user@example.com /etc/ssl/certs
sh /tmp/ssl_cert.sh issue example.com
# → 표시된 TXT 레코드를 DNS에 등록한 후:
sh /tmp/ssl_cert.sh verify example.com
```

기타 명령어:

```sh
sh /tmp/ssl_cert.sh show              # 현재 설정 확인
sh /tmp/ssl_cert.sh delete example.com  # 저장된 인증서 삭제
sh /tmp/ssl_cert.sh help              # 사용법 출력
```

## 와일드카드 도메인

`*.example.com` 입력 시 `*.example.com`과 `example.com` 모두에 대한 인증서를 발급합니다.

```sh
sh /tmp/ssl_cert.sh issue '*.example.com'
sh /tmp/ssl_cert.sh verify '*.example.com'
```

## 오류 대처

**TXT 레코드 검증 실패**
DNS 전파가 아직 완료되지 않았을 수 있습니다. 수 분 후 메뉴 3을 재시도하세요.

**`retryafter=86400` 오류**
반복된 검증 실패로 ZeroSSL이 요청을 제한하고 있습니다. 메뉴 2를 다시 실행해 새 TXT 레코드를 받고 DNS를 업데이트한 뒤 메뉴 3을 재시도하거나, 수 시간 후 메뉴 3을 재시도하세요.
