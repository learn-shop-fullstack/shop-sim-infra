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
  compose.obs.yml       # Prometheus, Loki, OTel Collector
cloudflared/            # Cloudflare Tunnel 설정 (호스트명 → 서비스)
opensearch/             # 분석기 설정, 동의어·사용자 사전
observability/          # Prometheus 스크레이프·알림 규칙, Loki 설정
scripts/
  deploy/               # 배포 에이전트: PC가 GHCR의 새 이미지를 받아 교체 (pull 방식)
  backup/               # Postgres 백업 → R2, 복구 절차
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

## 미결정

- [ ] 배포 에이전트 도구 (pull 방식, ADR 0014)
- [ ] 리버스 프록시(Caddy) 필요 여부 — 터널이 호스트명 라우팅을 대신할 수 있다
- [ ] `p-stack.dev` 하위 도메인 구성 (api / store / seller / admin, staging)

## 현재 단계

0단계: arm64 호환 확인 → 1단계: 로컬 compose, Cloudflare Tunnel, 배포 에이전트, 백업, 재사용 워크플로. (Oracle은 용량 부족으로 쓰지 않음, #1·ADR 0014)
