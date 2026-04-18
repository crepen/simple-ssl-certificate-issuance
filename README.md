# SSL 인증서 발급 도구

acme.sh를 이용해 ZeroSSL에서 DNS TXT 방식으로 SSL 인증서를 발급하는 셸 스크립트입니다.
Linux 및 Docker 컨테이너 환경에서 별도의 패키지 설치 없이 동작합니다.

## 특징

- POSIX sh 호환 (bash 불필요, dash 환경 포함)
- `curl` / `wget` 미설치 시 패키지 매니저로 자동 설치
- acme.sh 자동 설치 (cron 없이 강제 설치)
- ZeroSSL 계정 자동 등록
- 와일드카드 도메인 지원 (`*.example.com`)
- TXT 챌린지 발급과 인증서 발급을 단계별로 분리 실행
- 발급된 인증서를 도메인별 디렉토리에 저장

## 요구사항

- `sh` (POSIX 호환 셸)
- `curl` 또는 `wget` — 없을 경우 아래 패키지 매니저 중 하나가 있으면 자동 설치됩니다

| 패키지 매니저 | 대상 배포판 |
|--------------|------------|
| `apt-get` | Debian / Ubuntu |
| `apk` | Alpine Linux |
| `yum` | CentOS / RHEL (구버전) |
| `dnf` | Fedora / RHEL 8+ |
| `zypper` | openSUSE |

## 사용법

### 로컬 파일로 실행

```sh
sh ssl_cert.sh
```

### 파일 저장 없이 바로 실행 (curl)

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

### 파일 저장 없이 바로 실행 (wget)

```sh
wget -qO /tmp/ssl_cert.sh https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh && sh /tmp/ssl_cert.sh
```

> 스크립트가 대화형 입력을 사용하므로 파이프(`| sh`) 방식은 동작하지 않습니다.
> 위 방법처럼 임시 파일로 받아 실행하는 방식을 사용하세요.

### 비대화형 (인수 직접 전달)

메뉴 없이 명령어와 인수를 직접 전달하여 실행할 수 있습니다.

```sh
# 설정 저장
sh ssl_cert.sh config user@example.com /etc/ssl/certs

# TXT 챌린지 발급
sh ssl_cert.sh issue example.com
sh ssl_cert.sh issue '*.example.com'

# TXT 검증 및 인증서 발급
sh ssl_cert.sh verify example.com

# 저장된 인증서 삭제
sh ssl_cert.sh delete example.com

# 현재 설정 확인
sh ssl_cert.sh show
```

curl로 다운로드 후 바로 비대화형 실행:

```sh
curl -fsSL https://raw.githubusercontent.com/crepen/simple-ssl-certificate-issuance/main/ssl_cert.sh -o /tmp/ssl_cert.sh
sh /tmp/ssl_cert.sh config user@example.com /etc/ssl/certs
sh /tmp/ssl_cert.sh issue example.com
sh /tmp/ssl_cert.sh verify example.com
```

---

### 대화형 메뉴

인수 없이 실행하면 메뉴가 표시됩니다.

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

## 메뉴 설명

### 1. 설정 (이메일, 인증서 저장 경로)

ZeroSSL 계정에 사용할 이메일 주소와 인증서를 저장할 기본 경로를 입력합니다.
설정은 `~/.ssl_cert_config`에 저장되며 이후 실행 시 자동으로 불러옵니다.

### 2. TXT 챌린지 문자열 발급

도메인을 입력하면 ZeroSSL에서 DNS TXT 레코드 값을 발급합니다.

1. 도메인 입력 (예: `example.com` 또는 `*.example.com`)
2. acme.sh 설치 여부 확인 및 자동 설치
3. TXT 레코드 값 출력

출력된 TXT 레코드를 DNS에 등록한 뒤 메뉴 3을 실행합니다.

> 이전 발급 시도의 캐시를 완전히 제거하고 새로운 챌린지를 생성합니다.

### 3. TXT 검증 및 인증서 발급

DNS에 TXT 레코드를 등록한 후 실행합니다.

1. 도메인 입력 (메뉴 2에서 입력한 것과 동일)
2. ZeroSSL에서 TXT 레코드 검증
3. 인증서 발급 및 저장

발급된 파일은 `<인증서 저장 경로>/<도메인>/` 하위에 저장됩니다.

| 파일 | 설명 |
|------|------|
| `cert.pem` | 인증서 |
| `key.pem` | 개인 키 |
| `fullchain.pem` | 풀체인 인증서 |
| `ca.pem` | CA 인증서 |

### 4. 현재 설정 확인

저장된 이메일, 인증서 경로, acme.sh 설치 상태를 표시합니다.

### 5. 저장된 인증서 삭제

저장된 도메인 목록을 번호로 표시하고, 선택한 도메인의 인증서 파일을 삭제합니다.

## 발급 절차

```
[메뉴 1] 이메일 및 인증서 저장 경로 설정
    ↓
[메뉴 2] 도메인 입력 → TXT 레코드 값 발급
    ↓
DNS에 TXT 레코드 등록 (수동)
    ↓
DNS 전파 대기 (수 분 소요)
    ↓
[메뉴 3] 도메인 입력 → TXT 검증 → 인증서 발급 및 저장
```

## 와일드카드 도메인

`*.example.com` 입력 시 `*.example.com`과 `example.com` 모두에 대한 인증서를 발급합니다.
인증서는 `<저장 경로>/wildcard.example.com/` 디렉토리에 저장됩니다.

## 설정 파일 위치

| 경로 | 내용 |
|------|------|
| `~/.ssl_cert_config` | 이메일, 인증서 저장 경로 |
| `~/.acme.sh/` | acme.sh 설치 디렉토리 |

## 오류 대처

### `retryafter=86400` 오류

ZeroSSL이 이전 실패한 검증 시도를 캐싱하여 24시간 재시도를 거부하는 경우입니다.

- 메뉴 2를 다시 실행해 새로운 TXT 챌린지를 생성하고 DNS를 업데이트한 뒤 메뉴 3을 재시도합니다.
- 또는 수 시간 후 메뉴 3을 재시도합니다.
