# 개발용 데이터 스택 (`compose/local`)

앱 레포(api·web·loadtest)가 개발할 때 띄우는 데이터 스택이다. compose 프로젝트 이름은 `shop-sim-dev`라서 운영 compose와 볼륨이 섞이지 않는다. 모든 포트는 127.0.0.1에만 열린다.

## 실행과 정리

`.env`는 이 디렉터리에서 읽으므로, 다른 레포에서 실행해도 `-f`로 이 파일을 가리키면 된다.

```sh
cp .env.example .env                       # 처음 한 번
docker compose up -d --build --wait        # 기본 서비스 5개가 healthy가 될 때까지 기다린다
docker compose --profile tools up -d --wait kafka-ui opensearch-dashboards   # UI가 필요할 때만

docker compose --profile tools down        # 정리. profile을 빼면 UI 컨테이너가 남는다
docker compose --profile tools down -v     # 데이터까지 초기화
```

## 접속 주소

| 서비스 | 호스트에서 실행하는 앱 | compose 안의 컨테이너 | 비고 |
|---|---|---|---|
| Postgres | `postgres://postgres:postgres@localhost:5432/shop_sim` | `postgres:5432` | 계정 값은 볼륨이 빈 첫 실행 때만 적용 |
| Redis | `redis://localhost:6379` | `redis:6379` | `maxmemory 150mb`, `noeviction` |
| S3 (SeaweedFS) | `http://localhost:8333` | `seaweedfs:8333` | 키·버킷은 `.env`. 버킷 자동 생성 꺼짐 |
| Kafka | `localhost:9092` | `kafka:19092` | 토픽 자동 생성 꺼짐 |
| OpenSearch | `http://localhost:9200` | `opensearch:9200` | 보안 플러그인 꺼짐(http, 인증 없음) |
| Kafka UI | http://localhost:8080 | — | `tools` profile, 기본 읽기 전용 |
| OpenSearch Dashboards | http://localhost:5601 | — | `tools` profile |

## 운영과 다르게 동작하는 것

- **S3 클라이언트**: AWS SDK v3는 `forcePathStyle: true`. presigned URL을 만드는 클라이언트는 `requestChecksumCalculation: 'WHEN_REQUIRED'`와 `signableHeaders: new Set(['content-type', 'content-length'])`가 필요하다(#2)
- **Kafka 토픽**: 자동 생성이 꺼져 있어 토픽을 코드로 먼저 만들어야 한다. 없는 토픽에 보내면 `UNKNOWN_TOPIC_OR_PARTITION`
- **Kafka UI 쓰기**: 실험할 때만 `.env`에 `KAFKA_UI_READONLY=false`를 넣고 다시 띄운다

## 자주 겪는 문제

- **포트 충돌**: 다른 컨테이너가 같은 포트를 쓰면 시작에 실패한다. `.env`의 `*_PORT`를 바꾸되, Kafka는 광고 주소도 이 값을 따르므로 앱의 접속 주소도 함께 바꾼다
- **OpenSearch 첫 실행이 느리다**: Nori 플러그인을 넣은 이미지(`opensearch/Dockerfile`)를 처음 한 번 빌드한다
- **`CLUSTER_ID`나 Postgres 계정을 바꿨더니 시작이 안 된다**: 기존 볼륨과 맞지 않는다. `down -v`로 초기화한다
