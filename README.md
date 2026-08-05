# togethertrip

A new Flutter project.

## Local run

Create a local config file first:

```bash
cp config/local.example.json config/local.json
```

Run the app with local `dart-define` values:

```bash
./scripts/run_app.sh
```

`SUPPORT_EMAIL`에는 실제 수신 가능한 운영 고객지원 주소를 설정합니다. 값이 비어 있으면 앱은 연락처 준비 안내를 표시합니다.

계정 삭제와 스토어 정책 링크는 아래 dart-define으로 재정의할 수 있습니다. 생략하면
`https://togethertrip.co.kr`의 기본 공개 경로를 사용합니다.

- `PRIVACY_POLICY_URL`
- `TERMS_OF_SERVICE_URL`
- `COMMUNITY_POLICY_URL`
- `CUSTOMER_SUPPORT_URL`
- `ACCOUNT_DELETION_URL`

The script automatically selects the first iPhone listed by `flutter devices`
when no device option is provided.

Flutter run options can be passed through:

```bash
./scripts/run_app.sh -d chrome
./scripts/run_app.sh -d ios --debug
```

## Flutter Web 운영 배포

운영 웹 앱은 다음 명령과 같은 설정으로 빌드되며 `https://app.togethertrip.co.kr`에서 제공합니다.

```bash
flutter build web \
  --release \
  --dart-define=API_BASE_URL=https://api.togethertrip.co.kr \
  --dart-define=SUPPORT_EMAIL=운영_고객지원_주소
```

`main` 브랜치가 갱신되면 GitHub Actions가 빌드 결과를 S3에 동기화하고 CloudFront 캐시를 무효화합니다.

- Secret: `AWS_ROLE_ARN`
- Variables: `AWS_REGION`, `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`, `DEPLOY_ENABLED`, `SUPPORT_EMAIL`

인프라와 저장소 설정을 완료하기 전에는 `DEPLOY_ENABLED`를 비워 두고, 실제 배포를 시작할 때 `true`로 설정합니다.
`SUPPORT_EMAIL`은 운영 웹 빌드에 주입되므로 배포 전에 실제 수신 가능한 고객지원 주소를 GitHub Actions repository variable로 설정해야 합니다.

AWS 리소스와 OIDC 역할은 `togethertrip-infra`의 `web` Terraform 스택에서 관리합니다.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
