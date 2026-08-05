# 이슈 #56 출시 설정 하드닝 계획

## 연결 이슈

- App #56: App Store·Google Play 출시 빌드 및 심사 준비
- App #55: 공개 계정 삭제 URL 앱 내 진입점 보완

## 목표

- 마이 화면에서 공개 계정 삭제 안내를 탈퇴 실행 여부와 무관하게 찾을 수 있게 한다.
- 출시 화면에서 동작하지 않는 알림 설정 메뉴를 제거한다.
- Android release가 upload key 없이는 서명 산출물을 만들지 못하게 하고 cleartext를 차단한다.
- iOS release에 production APNs entitlement와 앱 Privacy Manifest를 적용한다.
- 필수 운영 설정을 정적 검증하고 출시·rollback 절차를 재현 가능한 문서로 남긴다.

## 범위

1. 마이 화면
   - `계정 삭제 안내` 메뉴를 공개 URL에 연결한다.
   - `알림 설정 기능은 아직 준비 중` 메뉴를 출시 UI에서 제거한다.
   - URL 실행 성공·실패와 메뉴 노출을 widget test로 검증한다.
2. Android
   - `android/key.properties` 또는 대응 환경 변수에서 upload signing 값을 읽는다.
   - release task에서 값/keystore 누락 시 명확히 실패한다.
   - main manifest는 cleartext를 차단하고 debug/profile overlay에서만 로컬 HTTP를 허용한다.
3. iOS
   - development와 production APNs entitlement를 분리한다.
   - Release/Profile 구성에 production entitlement를 연결한다.
   - 앱 `PrivacyInfo.xcprivacy`를 Runner 리소스에 포함한다.
4. 운영 설정·문서
   - release dart-define, signing, cleartext, entitlement, privacy manifest를 검사하는 스크립트를 추가한다.
   - 출시 체크리스트와 rollback 절차, 외부 콘솔에서 별도 검증할 항목을 문서화한다.

## 제외 범위

- upload key, 인증서, provisioning profile, Firebase/Kakao/Google Maps 실제 운영 비밀값 생성 또는 커밋
- App Store Connect/Play Console 설정 변경과 업로드
- 신규 알림 설정 상품 기능
- 스토어 스크린샷·심사 계정의 실제 생성

## 아키텍처 판단

- 공개 링크는 기존 `PublicSiteLinks`와 `ExternalLinkLauncher` 경계를 재사용한다.
- 알림 설정은 별도 화면이나 플랫폼 채널을 추가하지 않고 미완성 진입점만 제거한다.
- release 검증은 런타임 화면 계층이 아니라 `tool/`의 독립 스크립트와 플랫폼 build 설정에 둔다.
- 실제 비밀값은 gitignored 로컬 파일 또는 CI 환경 변수로만 주입한다.

## TDD 및 검증 계획

1. 계정 삭제 안내 메뉴 URL 실행과 미완성 알림 메뉴 부재를 검증하는 widget test를 먼저 추가한다.
2. release 설정 검증 스크립트가 정상 fixture와 필수 값 누락 fixture를 구분하도록 단위 테스트한다.
3. 구현 후 다음 명령을 실행한다.
   - `flutter test test/features/my/account_deletion_screen_test.dart`
   - `flutter test test/tool/release_config_validator_test.dart`
   - `dart run tool/verify_release_config.dart --platform-only`
   - 실제 비밀값 준비 후 `dart run tool/verify_release_config.dart --dart-define-file=config/release.json --android-key-properties=android/key.properties`
   - `flutter analyze`
   - `flutter test`

## 외부 검증으로 남는 항목

- 실제 upload key로 서명된 AAB와 Play pre-launch report
- Distribution 인증서/provisioning profile을 사용한 iOS Archive validation과 TestFlight 설치
- production APNs, Firebase, Kakao, Google Maps 콘솔의 bundle/package 제한
- 카카오·Apple 계정 탈퇴 실제 기기 E2E
- 스토어 메타데이터, 개인정보 라벨/Data Safety, 심사 계정
