# 배포 에이전트 (`scripts/deploy/`)

infra main이 배포 상태다(ADR 0025). `agent.sh`가 1분마다 운영 전용 클론을 main에 맞추고, 환경마다 마지막으로 적용한 커밋과 다르면 `compose pull`·`up --wait`를 한다. 배포·되돌리기는 PR 머지·revert로 한다.

| 경로 | 내용 |
|---|---|
| `~/.local/share/shop-sim/infra` | 운영 전용 클론. 손으로 고치지 않는다(실행마다 main으로 덮는다) |
| `~/.local/state/shop-sim/deploy/<환경>` | 마지막으로 적용한 커밋 |
| `~/Library/Logs/shop-sim-deploy-agent.log` | 적용 시작·성공·실패 로그 |

## 설치 (한 번, PC에서)

비밀 env 파일이 먼저 있어야 한다(`scripts/secrets/README.md`).

```sh
label=dev.p-stack.shop-sim.deploy-agent
git clone https://github.com/learn-shop-fullstack/shop-sim-infra.git ~/.local/share/shop-sim/infra
sed "s|__HOME__|$HOME|g" ~/.local/share/shop-sim/infra/scripts/deploy/$label.plist > ~/Library/LaunchAgents/$label.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$label.plist
```

확인: `launchctl print gui/$(id -u)/$label | grep -E 'state|last exit'`, `tail -f ~/Library/Logs/shop-sim-deploy-agent.log`

## 운영

- 실패한 커밋은 다시 시도하지 않는다. 고치는 PR을 머지하거나, 같은 상태로 다시 적용하려면 `rm ~/.local/state/shop-sim/deploy/<환경>`
- 배포를 멈춘다(장애 대응 중 등): `launchctl bootout gui/$(id -u)/$label`. 다시 켤 때는 설치의 `bootstrap` 줄
- 해제: `bootout` 뒤 `~/Library/LaunchAgents/$label.plist`를 지운다. 클론과 상태 디렉터리는 남아도 된다
- plist를 바꾸면 운영 클론에는 자동 반영되지만 `~/Library/LaunchAgents/`의 사본은 그대로다. `bootout` → 설치의 `sed`·`bootstrap`을 다시 한다
- 로그는 회전하지 않는다. 커지면 비운다(`: > ~/Library/Logs/shop-sim-deploy-agent.log`)
