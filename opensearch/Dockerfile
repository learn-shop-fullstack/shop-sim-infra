# 한국어 형태소 분석기(Nori)를 넣은 OpenSearch 이미지 (ADR 0006)
# 플러그인 버전은 OpenSearch 버전과 같아야 하므로 베이스 태그를 바꾸면 다시 빌드한다.
# 번들 플러그인은 유지한다: 지우면 대기 메모리가 약 160MB 줄지만 버전마다 제거 목록을 관리해야 한다(#4)
FROM opensearchproject/opensearch:3.9.0
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch analysis-nori
