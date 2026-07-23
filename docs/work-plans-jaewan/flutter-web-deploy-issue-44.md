# Flutter Web 운영 배포 계획

## 연결 이슈

- together-trip/togethertrip-client-flutter#44

## 목표

- 기존 Flutter 앱을 웹으로 빌드해 `app.togethertrip.co.kr`에 배포한다.
- 웹 앱의 API 진입점은 `https://api.togethertrip.co.kr`로 고정한다.
- 장기 AWS 키 없이 GitHub OIDC 역할로 S3와 CloudFront에 배포한다.

## 변경 범위

- 기존 Flutter CI에 `develop` 검증과 Flutter Web 빌드를 추가한다.
- `main` push 또는 수동 실행에서만 S3 배포와 CloudFront 무효화를 수행한다.
- 인프라 준비 전에는 `DEPLOY_ENABLED` 안전장치로 실제 업로드를 차단한다.
- README에 로컬 웹 빌드와 GitHub 설정을 기록한다.

## 검증

- `flutter analyze`
- `flutter test`
- `flutter build web --release --dart-define=API_BASE_URL=https://api.togethertrip.co.kr`

## 제외 범위

- 모바일 앱 기능과 UI는 변경하지 않는다.
- AWS 리소스 생성과 DNS 변경은 인프라 저장소에서 수행한다.
