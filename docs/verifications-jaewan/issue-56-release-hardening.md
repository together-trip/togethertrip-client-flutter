# 이슈 #56 출시 설정 하드닝 검증

## 검증 대상

- App #55 공개 계정 삭제 URL의 마이 화면 진입점
- 미완성 알림 설정 출시 UI 제거
- Android upload signing, release HTTPS, debug/profile 로컬 HTTP
- iOS production APNs entitlement와 앱 Privacy Manifest
- release 운영 값·플랫폼 설정 검증기
- 출시 체크리스트와 rollback 절차

## 실행한 명령

```bash
flutter analyze
flutter test
dart run tool/verify_release_config.dart --platform-only
dart run tool/verify_release_config.dart \
  --dart-define-file=config/release.example.json \
  --android-key-properties=android/key.properties.example
./gradlew :app:processDebugMainManifest
./gradlew :app:bundleRelease
plutil -lint ios/Runner/Runner.entitlements \
  ios/Runner/RunnerRelease.entitlements \
  ios/Runner/PrivacyInfo.xcprivacy
xcodebuild -project ios/Runner.xcodeproj \
  -target Runner -configuration Release -showBuildSettings
flutter build ios --release --no-codesign \
  --dart-define-from-file=config/release.example.json
git diff --check origin/develop...HEAD
git check-ignore config/release.json android/key.properties \
  android/app/google-services.json ios/Runner/GoogleService-Info.plist
```

## 결과

- `flutter analyze`: 성공, issue 0개
- `flutter test`: 성공, 208개 테스트 통과
- 계정 삭제 화면 테스트: 공개 URL 실행, 알림 설정 메뉴 부재, 링크 실패, 중복 탈퇴 방지 통과
- release 검증기 테스트: 4개 통과
- 플랫폼 전용 release 정적 검증: 통과
- 예시 release 설정 검증: 의도대로 실패
  - Kakao/Google Maps placeholder 탐지
  - signing password placeholder와 keystore 부재 탐지
- Android debug manifest 병합: 성공, cleartext 허용 유지
- Android release task: 실제 signing 값 부재를 명확한 오류로 거부
- iOS plist/entitlement lint: 모두 성공
- Privacy Manifest: 앱/서버 계약에 없는 `EmailAddress` 제거 및 검증기 회귀 테스트 추가
- 유지한 수집 유형 근거: nickname(`Name`), 인증 사용자 식별자(`UserID`), 장소 좌표(`PreciseLocation`), 프로필·기록 첨부(`PhotosorVideos`), 기록·댓글·신고 설명(`OtherUserContent`)
- Xcode Release build settings: `Runner/RunnerRelease.entitlements`, `com.togethertrip.togethertrip` 확인
- 비밀 파일 네 종류: 모두 gitignore 대상 확인
- diff whitespace 검사: 통과

## 실패 또는 미검증 항목

- iOS 무서명 release build는 로컬 Xcode에 iOS 26.5 platform이 없어 실패했다.
- 실제 Android upload key가 없어 signed AAB를 생성하지 않았다.
- Distribution 인증서/provisioning profile이 없어 iOS Archive validation과 TestFlight 설치를 수행하지 않았다.
- 운영 Firebase/APNs/Kakao/Google Maps 콘솔 설정과 package/bundle 제한은 외부 콘솔에서 확인해야 한다.
- 실제 기기 카카오·Apple 탈퇴, 푸시, 위치·사진 권한 E2E는 미검증이다.
- 스토어 스크린샷, 설명, 개인정보 라벨/Data Safety, 심사 계정은 준비하지 않았다.

## 다음 조치

1. Xcode Settings > Components에서 iOS 26.5 platform을 설치한다.
2. `config/release.json`, `android/key.properties`, 운영 Firebase 파일을 안전하게 주입한다.
3. 전체 release 검증기를 통과시킨 뒤 signed AAB와 iOS Archive를 생성한다.
4. Play closed test/TestFlight 및 실제 기기 E2E를 수행한다.
5. 스토어 메타데이터와 개인정보 선언을 최종 대조한다.
