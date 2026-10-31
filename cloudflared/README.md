# Cloudflare Tunnel (`cloudflared/`)

환경마다 locally-managed named tunnel 하나를 쓴다(ADR 0022). 이 폴더의 `<환경>.yml`이 호스트명 → 서비스 매핑의 원본이다. 대시보드에서 매핑을 고치지 않는다.

| 환경 | 터널 이름 | 호스트명 |
|---|---|---|
| production | `shop-sim-production` | `shop-{api,store,seller,admin}.p-stack.dev` |
| staging | `shop-sim-staging` | `shop-staging-{api,store,seller,admin}.p-stack.dev` |

## 터널 만들기 (환경마다 한 번, 사람이 실행)

Cloudflare 계정 로그인이 필요해 배포 자동화에 넣지 않는다. CLI는 설치하지 않고 mise로 실행한다.

```sh
cf() { mise exec cloudflared@2026.10.6 -- cloudflared "$@"; }

# 1. 계정 인증서(~/.cloudflared/cert.pem). 브라우저에서 p-stack.dev 영역을 고른다. 한 번만 한다
cf tunnel login

# 2. 터널 생성. 출력된 UUID를 <환경>.yml의 tunnel:에 적고 커밋한다
#    자격 증명은 ~/.cloudflared/<UUID>.json에 생긴다
cf tunnel create shop-sim-production

# 3. 호스트명마다 터널을 가리키는 CNAME(proxied)을 만든다
for h in api store seller admin; do cf tunnel route dns shop-sim-production "shop-$h.p-stack.dev"; done
```

staging은 이름을 `shop-sim-staging`으로, 호스트명을 `shop-staging-$h.p-stack.dev`로 바꿔 2·3을 반복한다.

## 비밀 파일

- `cert.pem`: 터널 생성·DNS 등록에만 쓴다. 컨테이너와 레포에 두지 않는다
- 자격 증명 `<UUID>.json`: 터널을 띄우는 데 필요한 비밀값이다. 레포 밖에 두고 경로를 env 파일의 `CLOUDFLARED_CREDENTIALS_FILE`에 적는다. 보관 위치는 비밀값 관리 항목에서 정한다
- 자격 증명을 잃으면 `cf tunnel delete`로 지우고 다시 만든다(UUID가 바뀌므로 `<환경>.yml`과 DNS도 다시)

## 주의

- `tunnel:`에는 UUID를 적는다. 이름을 적으면 이름을 ID로 바꾸려고 `cert.pem`을 찾아 컨테이너가 시작하지 않는다. UUID는 CNAME 대상(`<UUID>.cfargotunnel.com`)으로 공개되는 값이라 커밋해도 된다
- `route dns`는 같은 이름의 DNS 레코드가 이미 있으면 실패한다. 대시보드에서 기존 레코드를 확인한다
- 설정을 고친 뒤 검사: `docker run --rm -v "$PWD/production.yml:/etc/cloudflared/config.yml:ro" cloudflare/cloudflared:2026.10.6 tunnel --config /etc/cloudflared/config.yml ingress validate`
