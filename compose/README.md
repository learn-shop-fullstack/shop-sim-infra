# 운영 compose (`compose/`)

staging·production이 쓰는 역할별 compose 파일이다. 개발용 스택은 `local/`(사용법 `local/README.md`)이고 프로젝트가 따로라 섞이지 않는다.

| 파일 | 서비스 |
|---|---|
| `compose.data.yml` | Postgres, Redis, Kafka(KRaft), OpenSearch(+Nori) |
| `compose.app.yml` | api, worker, store, seller, admin |
| `compose.staging.yml` | staging 덮어쓰기: 메모리 상한·힙만 줄인다(ADR 0026) |
| `compose.obs.yml` | (13단계) Prometheus, Loki, OTel Collector |

## 실행

두 파일을 같은 프로젝트로 합쳐 띄운다. 프로젝트 이름(`-p`)으로 환경을 나누고, 볼륨·네트워크 이름도 이 이름을 따른다.

```sh
docker compose -p <프로젝트> --env-file <비밀 env> --env-file ../deploy/<환경>.env -f compose.data.yml -f compose.app.yml up -d --wait
docker compose -p <프로젝트> --env-file <비밀 env> --env-file ../deploy/<환경>.env -f compose.data.yml -f compose.app.yml ps
```

staging은 `-f compose.staging.yml`을 마지막에 덧붙인다. 배포 에이전트는 `compose.<환경>.yml`이 있으면 자동으로 붙인다.

- `ps`·`logs`·`down`도 같은 `-p`·`--env-file`·`-f`를 준다. 필수 변수(`${…:?}`)가 비면 어떤 명령이든 실패한다
- env 파일은 두 개다. 비밀 env는 `~/.config/shop-sim/<환경>/compose.env`(만들기·바꾸기는 `scripts/secrets/README.md`, 변수 목록은 `.env.example`), 배포 상태는 `../deploy/<환경>.env`(앱 이미지 태그). 같은 변수가 두 파일에 있으면 뒤에 준 파일이 이긴다
- 앱 이미지 없이 설정만 확인: `docker compose --env-file .env.example -f compose.data.yml -f compose.app.yml config -q`. 이미지 변수가 없어 실패하므로 `API_IMAGE=x WORKER_IMAGE=x STORE_IMAGE=x SELLER_IMAGE=x ADMIN_IMAGE=x`를 앞에 붙인다

## 네트워크 (ADR 0027)

| 네트워크 | 선언 | 서비스 |
|---|---|---|
| `edge` | `compose.app.yml`, 외부 출구 있음 | cloudflared, api, worker, store, seller, admin |
| `data` | `compose.data.yml`, `internal: true`(외부 출구 없음) | postgres, redis, kafka, opensearch, api, worker |

- 새 서비스는 `networks`를 꼭 적는다. 빠뜨리면 `default` 네트워크에 혼자 붙어 아무와도 통신하지 못한다. 데이터 서비스는 `data`만, 터널이 가리키는 서비스는 `edge`, 데이터 서비스를 쓰는 앱은 둘 다
- 소속 확인: `config --format json | jq -r '.services | to_entries[] | "\(.key): \(.value.networks | keys | join(","))"'`(env는 위의 설정 확인과 같다). `default`가 나오면 빠뜨린 것이다

## 개발용(`local/`)과 다른 점

- 호스트 포트를 열지 않는다. 같은 프로젝트·같은 네트워크의 컨테이너만 서비스 이름(`postgres:5432`, `kafka:9092`, `opensearch:9200`)으로 접속한다
- Kafka 리스너는 컨테이너용 하나(`kafka:9092`)다
- 모든 서비스가 `restart: unless-stopped`다. SeaweedFS·UI 도구는 없다(운영 이미지 저장소는 R2)

## 주의

- `compose.app.yml`의 `depends_on`이 `compose.data.yml`의 postgres를 가리켜 app 파일만으로는 검사를 통과하지 않는다. 데이터 서비스를 다른 기계로 옮기면 `depends_on`을 지운다
- `DATABASE_URL`의 계정은 `POSTGRES_*`와 손으로 맞춘다. `POSTGRES_*`는 볼륨이 빈 첫 실행 때만 적용된다
- OpenSearch 이미지는 GHCR에서 받는다(`opensearch-image` 워크플로, #14). `opensearch/Dockerfile`을 바꾸면 머지 후 새 `sha-` 태그로 `compose.data.yml`을 고치는 PR을 낸다. 개발용 `compose/local/`은 그대로 PC에서 빌드한다
- web 이미지는 API 주소가 빌드에 들어가 환경마다 태그가 다르다(ADR 0020)
- 메모리 상한은 `architecture.md` 예산표를 따른다. 지금 합계 5.82GiB(데이터 4.2, 앱 1.62)
- staging 덮어쓰기에는 상한·힙만 둔다. `command`는 합쳐지지 않고 통째로 바뀌므로 redis 옵션을 공용 파일에서 바꾸면 여기도 고친다. 공용 파일을 고치면 두 환경 모두 `config`로 검사한다. staging 합계 3392MiB, 대기 실측은 #19
