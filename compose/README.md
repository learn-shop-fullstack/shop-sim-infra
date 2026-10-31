# 운영 compose (`compose/`)

staging·production이 쓰는 역할별 compose 파일이다. 개발용 스택은 `local/`(사용법 `local/README.md`)이고 프로젝트가 따로라 섞이지 않는다.

| 파일 | 서비스 |
|---|---|
| `compose.data.yml` | Postgres, Redis, Kafka(KRaft), OpenSearch(+Nori) |
| `compose.app.yml` | api, worker, store, seller, admin |
| `compose.obs.yml` | (13단계) Prometheus, Loki, OTel Collector |

## 실행

두 파일을 같은 프로젝트로 합쳐 띄운다. 프로젝트 이름(`-p`)으로 환경을 나누고, 볼륨·네트워크 이름도 이 이름을 따른다.

```sh
docker compose -p <프로젝트> --env-file <env 파일> -f compose.data.yml -f compose.app.yml up -d --wait
docker compose -p <프로젝트> --env-file <env 파일> -f compose.data.yml -f compose.app.yml ps
```

- `ps`·`logs`·`down`도 같은 `-p`·`--env-file`·`-f`를 준다. 필수 변수(`${…:?}`)가 비면 어떤 명령이든 실패한다
- env 파일은 `~/.config/shop-sim/<환경>/compose.env`(만들기·바꾸기는 `scripts/secrets/README.md`). 변수 목록은 `.env.example`
- 앱 이미지 없이 설정만 확인: `docker compose --env-file .env.example -f compose.data.yml -f compose.app.yml config -q`

## 개발용(`local/`)과 다른 점

- 호스트 포트를 열지 않는다. 같은 프로젝트의 컨테이너만 서비스 이름(`postgres:5432`, `kafka:9092`, `opensearch:9200`)으로 접속한다
- Kafka 리스너는 컨테이너용 하나(`kafka:9092`)다
- 모든 서비스가 `restart: unless-stopped`다. SeaweedFS·UI 도구는 없다(운영 이미지 저장소는 R2)

## 주의

- `compose.app.yml`의 `depends_on`이 `compose.data.yml`의 postgres를 가리켜 app 파일만으로는 검사를 통과하지 않는다. 데이터 서비스를 다른 기계로 옮기면 `depends_on`을 지운다
- `DATABASE_URL`의 계정은 `POSTGRES_*`와 손으로 맞춘다. `POSTGRES_*`는 볼륨이 빈 첫 실행 때만 적용된다
- OpenSearch 이미지는 아직 PC에서 빌드한다(`build: ../opensearch`). 재사용 워크플로가 생기면 GHCR 이미지로 바꾼다
- web 이미지는 API 주소가 빌드에 들어가 환경마다 태그가 다르다(ADR 0020)
- 메모리 상한은 `architecture.md` 예산표를 따른다. 지금 합계 5.82GiB(데이터 4.2, 앱 1.62)
