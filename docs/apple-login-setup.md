# Sign in with Apple 앱 설정

## 노출 정책

- iOS에서는 카카오 로그인과 같은 화면에 공식 `SignInWithAppleButton`을 동일 높이로 노출한다.
- Android에서는 Apple 로그인 버튼을 노출하지 않는다. Android용 Google 로그인은 별도 범위다.

## Apple Developer 설정

1. Apple Developer의 App Identifier `com.togethertrip.togethertrip`에 **Sign in with Apple** capability를 활성화한다.
2. Xcode의 Runner target에 `Runner.entitlements`가 연결돼 있는지 확인한다.
3. 서버의 `APPLE_CLIENT_ID`를 실제 배포 bundle identifier와 동일하게 설정한다.
4. provisioning profile을 capability 활성화 후 다시 생성한다.

앱은 매 로그인마다 `Random.secure()`로 원본 nonce를 만들고, Apple에는 SHA-256 해시만 전달한다. 서버에는 authorization code, identity token, 원본 nonce와 최초 승인에서만 받을 수 있는 이름을 전달한다. 사용자 취소는 오류로 표시하지 않으며, revoked credential은 재승인을 안내한다.

## 실제 기기 검증

- 신규 승인 후 `PROFILE_REQUIRED` 화면 이동
- 재로그인 후 `AUTHENTICATED` 화면 이동
- Apple 인증 시트 취소 시 오류 문구 미노출
- Apple ID 설정에서 앱 사용 중단 후 재로그인 안내
- 회원 탈퇴 후 로컬 TogetherTrip 토큰 삭제
