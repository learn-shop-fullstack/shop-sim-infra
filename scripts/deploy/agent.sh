#!/usr/bin/env bash
# 배포 에이전트 (ADR 0025): 운영 전용 infra 클론을 origin/main에 맞추고,
# 환경마다 마지막으로 적용한 커밋과 다르면 compose를 적용한다. launchd가 1분마다 실행한다.
# 실패해도 같은 커밋으로 다시 시도하지 않는다. 고치는 커밋(PR)이 들어오면 다시 적용한다.
set -euo pipefail

clone="${SHOP_SIM_DEPLOY_CLONE:-$HOME/.local/share/shop-sim/infra}"
secrets="${SHOP_SIM_SECRETS_DIR:-$HOME/.config/shop-sim}"
state="${SHOP_SIM_DEPLOY_STATE:-$HOME/.local/state/shop-sim/deploy}"
envs="${SHOP_SIM_DEPLOY_ENVS:-staging production}"

log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*"; }

# 환경 하나의 compose 명령. 비밀 env 다음에 배포 상태를 준다. 같은 변수는 뒤 파일이 이긴다(compose/README.md)
compose() {
  local env="$1"; shift
  docker compose -p "shop-sim-$env" \
    --env-file "$secrets/$env/compose.env" \
    --env-file "$clone/deploy/$env.env" \
    -f "$clone/compose/compose.data.yml" -f "$clone/compose/compose.app.yml" \
    "$@"
}

# Docker가 아직 안 떴으면(부팅 직후 등) 기록 없이 끝내 다음 실행에서 다시 본다
if ! docker info >/dev/null 2>&1; then
  log "docker에 연결할 수 없다. 다음 실행에서 다시 본다"
  exit 0
fi

# 운영 전용 클론이라 로컬 변경과 추적하지 않는 파일은 버린다. 네트워크 오류면 여기서 실패하고 다음 실행에서 다시 본다
git -C "$clone" fetch --quiet origin main
git -C "$clone" reset --quiet --hard origin/main
git -C "$clone" clean --quiet --force -d
head="$(git -C "$clone" rev-parse --short HEAD)"

mkdir -p "$state"
for env in $envs; do
  last="$(cat "$state/$env" 2>/dev/null || true)"
  [ "$last" = "$head" ] && continue

  log "$env: ${last:-없음} → $head 적용 시작"
  if compose "$env" pull --quiet &&
    compose "$env" up --detach --wait --wait-timeout 300 --remove-orphans; then
    log "$env: $head 적용 성공"
  else
    log "$env: $head 적용 실패. 고치는 커밋이 들어올 때까지 다시 시도하지 않는다"
  fi
  # 성공·실패 모두 기록해 같은 커밋을 반복 적용하지 않는다
  echo "$head" > "$state/$env"
done
