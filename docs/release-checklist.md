# TogetherTrip 앱 출시 체크리스트

이 문서는 App #56의 release artifact 생성 전후 절차를 기록한다. 실제 비밀값, keystore, 인증서, 심사 계정 비밀번호는 저장소에 커밋하지 않는다.

## 1. 도구와 버전

- [ ] `flutter --version`이 팀에서 확정한 stable 버전과 일치한다.
- [ ] Android SDK API 36과 프로젝트가 요구하는 JDK가 설치되어 있다.
- [ ] Xcode 26과 iOS 26 SDK가 설치되어 있다.
- [ ] `pubspec.yaml`의 `version`과 각 스토어의 이전 build number를 비교해 증가시켰다.
- [ ] 앱 이름, 아이콘, 스플래시가 최종 브랜드와 일치한다.
- [ ] iPhone/iPad 지원 범위와 대상 기기 레이아웃을 확정했다.

## 2. 비밀값과 운영 환경

1. `config/release.example.json`을 `config/release.json`으로 복사하고 실제 운영 값을 입력한다.
2. `android/key.properties.example`을 `android/key.properties`로 복사하고 upload key 정보를 입력한다.
3. `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`에 운영 Firebase 프로젝트 파일을 둔다.
4. 다음을 확인한다.

- [ ] `API_BASE_URL`이 운영 HTTPS gateway를 가리킨다.
- [ ] `SUPPORT_EMAIL`이 실제 수신 가능한 주소다.
- [ ] Kakao native app key의 Android package/iOS bundle 제한이 운영 앱과 일치한다.
- [ ] Google Maps key에 package/bundle 및 API 제한을 적용했다.
- [ ] Firebase Android/iOS 앱 ID, package/bundle이 운영 앱과 일치한다.
- [ ] Apple App ID에 Sign in with Apple과 Push Notifications capability가 활성화되어 있다.
- [ ] 공개 개인정보처리방침·약관·운영정책·지원·계정 삭제 URL이 모두 HTTPS 200을 반환한다.

커밋 전에는 다음 명령으로 추적 여부를 확인한다.

```bash
git status --short
git check-ignore config/release.json android/key.properties \
  android/app/google-services.json ios/Runner/GoogleService-Info.plist
```

## 3. 정적 검증

비밀값 없이 플랫폼 설정만 확인할 때:

```bash
dart run tool/verify_release_config.dart --platform-only
```

실제 release 입력값과 signing까지 확인할 때:

```bash
dart run tool/verify_release_config.dart \
  --dart-define-file=config/release.json \
  --android-key-properties=android/key.properties
flutter analyze
flutter test
```

검증기는 다음을 실패로 처리한다.

- 필수 dart-define 누락, 예시 placeholder, HTTP 운영 URL
- upload signing 값 또는 keystore 파일 누락
- Android debug signing 재사용 또는 release cleartext 허용
- iOS production APNs entitlement와 Privacy Manifest 연결 누락
- Firebase 플랫폼 설정 파일 누락

## 4. Android artifact

```bash
flutter build appbundle --release \
  --dart-define-from-file=config/release.json
```

- [ ] `build/app/outputs/bundle/release/app-release.aab`가 생성된다.
- [ ] `jarsigner -verify -verbose -certs`로 서명 상태를 확인한다.
- [ ] Play Console internal/closed track에 올리고 pre-launch report를 확인한다.
- [ ] Android 12, 13, 14, 15 이상에서 권한 허용·거부와 딥링크를 확인한다.

## 5. iOS artifact

```bash
flutter build ipa --release \
  --dart-define-from-file=config/release.json
```

- [ ] Distribution 인증서와 운영 provisioning profile로 Archive한다.
- [ ] Archive의 `aps-environment`가 `production`이다.
- [ ] Archive에 앱 및 포함 SDK의 `PrivacyInfo.xcprivacy`가 들어 있다.
- [ ] Xcode Organizer validation을 통과한다.
- [ ] TestFlight에서 설치·로그인·푸시 수신을 확인한다.

## 6. 사용자 E2E

- [ ] 카카오 신규 가입과 재로그인
- [ ] Apple 신규 가입과 재로그인
- [ ] 여행 생성 → 초대 → 기록/소비 → 정산
- [ ] 위치·사진·알림 권한 허용/거부
- [ ] UGC 신고와 사용자 차단/해제
- [ ] 카카오 계정 탈퇴 후 로컬 세션·푸시 토큰 정리
- [ ] Apple 계정 탈퇴 후 credential 및 서버 토큰 폐기
- [ ] 실패 후 탈퇴 재시도와 중복 탭 방지
- [ ] 마이 화면의 공개 정책·지원·계정 삭제 안내 링크

## 7. 스토어 제출

- [ ] 스크린샷, 설명, 카테고리, 연령 등급을 확정했다.
- [ ] App Privacy와 Google Play Data Safety가 실제 앱 권한·Privacy Manifest와 일치한다.
- [ ] 계정 삭제 URL과 고객지원 URL을 콘솔에 등록했다.
- [ ] 심사 계정과 핵심 흐름 설명을 안전한 전달 수단으로 제공했다.
- [ ] TestFlight/closed test 결과와 알려진 제한을 기록했다.
- [ ] [rollback 절차](./release-rollback.md)의 담당자와 판단 기준을 확인했다.
