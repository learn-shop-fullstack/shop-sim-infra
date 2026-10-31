# 운영 비밀값 (`scripts/secrets/`)

운영 비밀값의 원본은 PC의 `~/.config/shop-sim/<환경>/`이고, 백업은 비밀번호 관리자다(ADR 0023). 레포에는 변수 목록(`compose/.env.example`)만 둔다.

| 파일 | 내용 | 권한 |
|---|---|---|
| `~/.config/shop-sim/<환경>/` | 환경별 디렉터리 | 700 |
| `compose.env` | compose `--env-file`. DB 계정, 이미지, 터널 설정 이름·자격 증명 경로 | 600 |
| `cloudflared.json` | 터널 자격 증명(`cloudflared/README.md`) | 400 |

`~/.cloudflared/cert.pem`(계정 인증서)은 터널을 만들 때만 쓰고 여기에 두지 않으며 백업하지 않는다. 잃으면 `tunnel login`으로 다시 받는다.

## 처음 만들기

```sh
scripts/secrets/init-env.sh production   # 무작위 Postgres 비밀번호. 이미 있으면 실패한다
mv ~/.cloudflared/<UUID>.json ~/.config/shop-sim/production/cloudflared.json
```

두 파일을 비밀번호 관리자에 보관한다. staging도 같다.

## 변수를 더할 때

1. `compose/.env.example`에 변수와 예시 값을 더한다(PR)
2. 각 환경의 `compose.env`에 실제 값을 손으로 더한다
3. 비밀번호 관리자를 갱신한다

## 값을 바꿀 때

`compose.env`를 고치고 비밀번호 관리자도 갱신한다. 이슈에는 "바꿨다"만 남기고 값은 적지 않는다.

Postgres 비밀번호는 `POSTGRES_PASSWORD`가 볼륨이 빈 첫 실행 때만 적용되므로 DB도 함께 바꾼다.

```sh
openssl rand -hex 24                                           # 새 값
docker compose -p <프로젝트> --env-file <env 파일> -f compose.data.yml -f compose.app.yml \
  exec postgres psql -U shop_sim -d shop_sim -c "ALTER ROLE shop_sim PASSWORD '<새 값>'"
# compose.env의 POSTGRES_PASSWORD와 DATABASE_URL을 같은 값으로 고친 뒤 앱을 다시 띄운다
docker compose ... up -d --wait api worker
```

컨테이너 안의 `psql`은 localhost 접속이라 비밀번호 없이 들어간다(공식 이미지의 `trust`). 새 비밀번호가 적용됐는지는 api처럼 다른 컨테이너에서 `postgres` 호스트로 접속해 확인한다.

## PC를 잃었을 때

1. 비밀번호 관리자에서 파일을 꺼내 같은 경로·권한(위 표)으로 둔다
2. Postgres는 백업(R2)으로 복구한다. 백업의 DB 계정 비밀번호가 `compose.env`와 같은지 확인한다
