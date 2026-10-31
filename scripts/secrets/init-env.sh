#!/usr/bin/env bash
# 환경별 운영 env 파일을 만든다(ADR 0023). 이미 있으면 덮어쓰지 않는다.
# 변수 목록은 compose/.env.example이 원본이다. 우리가 정하는 비밀값은 무작위로 채우고,
# 나머지(이미지 등)는 예시 값 그대로 둔다
#
#   scripts/secrets/init-env.sh production
#   SHOP_SIM_SECRETS_DIR=/tmp/x scripts/secrets/init-env.sh staging   # 다른 위치(시험용)
set -euo pipefail

env="${1:-}"
case "$env" in
  production | staging) ;;
  *) echo "사용법: $0 <production|staging>" >&2; exit 2 ;;
esac

repo="$(cd "$(dirname "$0")/../.." && pwd)"
dir="${SHOP_SIM_SECRETS_DIR:-$HOME/.config/shop-sim}/$env"
file="$dir/compose.env"

if [ -e "$file" ]; then
  echo "이미 있다: $file (덮어쓰지 않는다. 값을 바꾸려면 직접 고치고 비밀번호 관리자도 갱신한다)" >&2
  exit 1
fi

# 이 셸이 만드는 파일·디렉터리를 소유자만 읽고 쓰게 한다(디렉터리 700, 파일 600)
umask 077
mkdir -p "$dir"
chmod 700 "$dir"

# hex라 URL(DATABASE_URL)에 넣어도 인코딩이 필요 없다. 24바이트 = 192비트
password="$(openssl rand -hex 24)"

# 예시 파일의 키를 기준으로 값만 바꾼다. 비밀값을 화면에 출력하지 않는다
sed \
  -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$password|" \
  -e "s|^DATABASE_URL=postgres://\([^:]*\):[^@]*@|DATABASE_URL=postgres://\1:$password@|" \
  -e "s|^CLOUDFLARED_CONFIG=.*|CLOUDFLARED_CONFIG=$env|" \
  -e "s|^CLOUDFLARED_CREDENTIALS_FILE=.*|CLOUDFLARED_CREDENTIALS_FILE=$dir/cloudflared.json|" \
  "$repo/compose/.env.example" > "$file"

echo "만들었다: $file"
echo "다음: 터널 자격 증명을 $dir/cloudflared.json 으로 옮기고, 두 파일을 비밀번호 관리자에 보관한다"
