# 워크플로 (`.github/workflows/`)

## `build-image.yml`: 이미지 빌드 → GHCR (재사용 워크플로, ADR 0024)

arm64 이미지를 빌드해 `ghcr.io/learn-shop-fullstack/shop-sim-<image>:sha-<7자>`로 올린다. 호출한 레포의 기본 브랜치에서만 올리고, PR에서는 빌드만 한다.

앱 레포에서 호출하는 법:

```yaml
jobs:
  image-api:
    permissions:
      contents: read
      packages: write # 재사용 워크플로는 이 job이 준 권한까지만 쓴다
    uses: learn-shop-fullstack/shop-sim-infra/.github/workflows/build-image.yml@main
    with:
      image: api # → ghcr.io/learn-shop-fullstack/shop-sim-api
      context: .
      file: apps/api/Dockerfile # 비우면 <context>/Dockerfile
```

- 입력은 추가만 한다. 지우거나 의미를 바꿀 때는 새 워크플로 파일을 만든다(앱 레포가 `@main`으로 부른다)
- 처음 올린 패키지는 private로 생긴다. 패키지 설정(Package settings → Change visibility)에서 public으로 바꾼다. 조직 설정(Settings → Packages → Package creation)에서 Public을 허용해 두었다(웹 UI라 파일에 흔적이 없다). **되돌릴 수 없다.** 이미지에 비밀값이 없는지 먼저 확인한다
- 패키지는 이미지 라벨(`org.opencontainers.image.source`)로 호출한 레포에 연결되고 그 레포의 접근 권한을 따른다. 서비스 이름 하나는 한 레포에서만 올린다

## `opensearch-image.yml`

`opensearch/`(Nori 이미지)를 위 워크플로로 빌드한다. 같은 레포라 `./` 경로로 불러, `build-image.yml`을 고친 PR에서도 바뀐 내용으로 실행된다.
