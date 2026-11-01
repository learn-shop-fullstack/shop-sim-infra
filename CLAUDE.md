# shop-sim-infra — 인프라 · 배포 · 관측성

멀티 판매자 마켓플레이스 **shop-sim**의 플랫폼(인프라) 레포. 회사에서 일한다고 가정하고 진행하는 학습 프로젝트다. 회사로 치면 플랫폼·SRE 팀이 소유하는 레포다.

공통 문서 (`../.github/handbook/`):
- 작업 방식: @../.github/handbook/working-agreement.md
- 시스템 구성·배포 환경·메모리 예산: `../.github/handbook/architecture.md`
- 작업 목록: `../.github/handbook/ROADMAP.md`의 `[infra]` 항목
- 결정 근거: `../.github/handbook/adr/` (특히 0014 배포. 0010은 대체됨)

## 이 레포의 책임

```
compose/
  local/                # 개발용 전체 스택 (앱 레포들이 이걸 띄워서 개발)
  compose.data.yml      # Postgres, Redis, Kafka(KRaft), OpenSearch(+Nori)
  compose.app.yml       # api, worker, store, seller·admin(정적), cloudflared
  compose.staging.yml   # staging 덮어쓰기: 메모리 상한·힙만
  compose.obs.yml       # (13단계) Prometheus, Loki, OTel Collector
cloudflared/            # Cloudflare Tunnel 설정 (호스트명 → 서비스)
opensearch/             # Nori 이미지(Dockerfile), 분석기 설정, 동의어·사용자 사전
observability/          # Prometheus 스크레이프·알림 규칙, Loki 설정
scripts/
  deploy/               # 배포 에이전트: PC가 GHCR의 새 이미지를 받아 교체 (pull 방식)
  backup/               # Postgres 백업 → R2, 복구 절차
  secrets/              # 운영 env 파일 생성, 비밀값 절차
.github/workflows/      # 재사용 워크플로: arm64 이미지 빌드 → GHCR 푸시
runbooks/               # 장애 대응 런북
k8s/                    # (14단계) k3s 매니페스트, Argo CD
```

## 운영 환경 요약

- 로컬 PC(Apple Silicon)에서 docker compose. **모든 이미지는 arm64**
- 환경: production + staging(같은 PC의 별도 compose 프로젝트). 개발용 컨테이너도 운영과 다른 compose 프로젝트로
- 외부 공개는 Cloudflare Tunnel(`p-stack.dev` 하위 도메인)로만. PC에 열린 포트 없음. 내부 서비스는 compose 내부 네트워크
- 배포는 pull 방식: CI는 GHCR 푸시까지, PC의 배포 에이전트가 교체. public 레포라 self-hosted runner는 두지 않는다
- 무료 부가 서비스: R2(이미지·백업), GHCR, GitHub Actions, Sentry 무료 플랜
- 부하 생성도 같은 PC에서 한다 (측정 해석 시 자원 경합 감안)

## 레포 규칙

- **메모리 예산을 지킨다.** 모든 컨테이너에 메모리 제한을 걸고, Kafka·OpenSearch 힙은 고정한다. 예산표는 `architecture.md` "배포 환경". 새 서비스를 추가하면 예산표를 먼저 갱신한다.
- **나눌 수 있게 구성한다.** compose는 역할별 파일로 나누고, 서비스 주소·포트는 전부 환경 변수로 받는다. 나중에 기계나 클러스터로 나눠도 앱 코드는 바뀌지 않아야 한다.
- **비밀값은 커밋하지 않는다.** 레포에는 `.env.example`만. 실제 값은 GitHub Secrets와 PC의 권한 제한된 파일.
- **사람이 손으로 배포하지 않는다.** 배포는 CI(재사용 워크플로)와 배포 에이전트만 한다. PC에서 손으로 바꾼 운영 설정은 이 레포에 반영될 때까지 미완료로 본다.
- 앱 레포는 이 레포의 재사용 워크플로를 호출만 하고, 배포 방식은 이 레포가 소유한다.
- 인프라 변경 리뷰 가이드에는 **되돌리는 방법**과 **다운타임 여부**를 반드시 포함한다.

## 결정사항

- 네트워크: 운영 compose는 `edge`(cloudflared·앱, 외부 출구 있음)와 `data`(데이터 서비스, `internal: true`)로 나누고 api·worker만 둘 다 붙는다. cloudflared는 데이터 서비스에 닿지 않는다. 새 서비스는 `networks`를 꼭 적는다(ADR 0027, #25). 규칙과 확인 명령은 `compose/README.md`
- 외부 공개: 환경마다 locally-managed Cloudflare Tunnel 하나. 호스트명 → 서비스 매핑의 원본은 `cloudflared/<환경>.yml`(대시보드에서 고치지 않는다). 호스트명은 `shop-{api,store,seller,admin}.p-stack.dev`, staging은 `shop-staging-…`(무료 인증서가 한 단계 하위 도메인만 덮는다). 리버스 프록시는 두지 않는다(ADR 0022, #10). 터널 생성 절차는 `cloudflared/README.md`
- 비밀값: 운영 원본은 PC의 `~/.config/shop-sim/<환경>/`(디렉터리 700, 파일 600), 백업은 비밀번호 관리자. Postgres 비밀번호는 `scripts/secrets/init-env.sh`가 무작위로 만든다. GitHub Secrets는 CI가 쓰는 값만(지금은 없음), 빌드 공개 값은 Variables. org 레포 전부 secret scanning·push protection(ADR 0023, #12). 절차는 `scripts/secrets/README.md`
- 이미지: 재사용 워크플로 `build-image.yml`이 `ubuntu-24.04-arm`에서 빌드해 `ghcr.io/learn-shop-fullstack/shop-sim-<서비스>:sha-<7자>`로 올린다. 기본 브랜치에서만 올리고 PR에서는 빌드만 한다. 움직이는 태그 없음, 패키지는 public(ADR 0024, #14). 호출법은 `.github/workflows/README.md`
- 배포: infra main이 배포 상태다(GitOps). 앱 이미지 태그는 `deploy/<환경>.env`, 비밀값은 레포 밖 env(compose에 비밀 env 다음 배포 상태 순으로 넘긴다). PC의 launchd가 1분마다 `scripts/deploy/agent.sh`로 운영 전용 클론을 main에 맞추고 바뀐 커밋을 `compose pull`·`up --wait`로 적용한다. 실패한 커밋은 다시 시도하지 않고 PR로 고치거나 되돌린다. compose 프로젝트 이름은 `shop-sim-<환경>`. 머지가 곧 배포이므로 리뷰 가이드의 다운타임은 머지 시점 기준으로 쓴다(ADR 0025, #17). 설치·일시정지는 `scripts/deploy/README.md`
- staging: 기능 확인용. 공용 compose는 production 값이고, `compose/compose.staging.yml`이 상한·힙만 줄인다(합계 3392MiB). 에이전트가 `compose.<환경>.yml`이 있으면 마지막 `-f`로 붙인다. 데이터 서비스도 환경마다 따로이고 성능은 staging으로 판단하지 않는다(ADR 0026, #19)

## 미결정

- [ ] 태그 PR 자동화: 앱 CI가 GitHub App 토큰으로 infra에 staging 태그 PR(ADR 0025). App 생성은 api·web 호출 항목에서

## 현재 단계

1단계 진행 중. 완료: 로컬 개발용 compose(#4, 사용법 `compose/local/README.md`), 역할별 운영 compose data·app(#8, 사용법 `compose/README.md`), Cloudflare Tunnel(#10, production·staging 터널과 DNS 생성, 앱이 없어 502까지 확인), 비밀값 관리(#12), 재사용 워크플로와 OpenSearch 이미지 GHCR 게시(#14), 배포 에이전트(#17, 앱 이미지가 없어 성공 경로는 미확인), 환경 분리(#19, staging 데이터 스택 대기 실측까지), 메모리 예산(#21, 데이터 스택 실측과 Postgres 설정. 앱 컨테이너는 첫 이미지 뒤). 남은 것: 네트워크, 백업, 앱 레포 호출.
