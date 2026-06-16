# Work Plan

## 작업

클라이언트 이슈 #13 `서버 인증 및 회원 프로필 API 변경 대응`을 진행한다.

- Client Issue: https://github.com/together-trip/togethertrip-client-flutter/issues/13
- Server Issue: https://github.com/together-trip/togethertrip-server-main/issues/61
- Server PR: https://github.com/together-trip/togethertrip-server-main/pull/62

## 배경

서버 인증 및 회원 프로필 흐름 안정화 작업으로 전화번호 원문 응답 제거, 사용자 응답 필드 변경, refresh token rotation, 프로필 이미지 업로드 지원이 추가되었다.

Flutter 앱은 기존에 인증번호 요청 응답의 `phoneNumber`, `UserProfile.phoneNumber`, JSON 기반 `PATCH /api/users/me`만 가정하고 있어 서버 PR #62 계약에 맞춘 수정이 필요하다.

## 범위

- 인증번호 요청 응답에서 원문 `phoneNumber` 제거 대응.
- 인증번호 확인 요청은 사용자가 입력한 정규화 전화번호를 앱 상태에 보관해 재전송한다.
- `UserProfile` 모델을 `phoneNumberMasked`, `phoneVerified`, `phoneVerifiedAt` 중심으로 갱신한다.
- 내 정보 수정에서 기존 JSON 요청을 유지하되, 새 프로필 이미지가 선택된 경우 `multipart/form-data`로 `profileImage`를 전송한다.
- 프로필 이미지 변경 UI를 개인정보 수정 화면에 추가한다.
- 서버 상대경로 프로필 이미지 URL을 앱에서 표시 가능한 URL로 변환한다.
- refresh token rotation 이후 401 응답 시 갱신과 1회 재시도 흐름을 반영한다.
- 관련 위젯/서비스 테스트를 서버 API 계약에 맞게 갱신한다.

## 제외 범위

- 프로필 이미지 삭제/초기화 기능. 이번 범위는 변경만 지원한다.
- 서버 API 계약 변경.
- 알림톡/SMS provider 연동.
- 마케팅 수신 동의, 알림 발송 이력, 재시도 정책.
- Kakao OAuth 외 provider 추가.

## 설계

1. 전화번호 인증 응답 계약 반영
   - `PhoneVerificationCodeSent`는 `expiresInSeconds`만 필수로 파싱한다.
   - `SignUpProfileScreen`은 `_toApiPhoneNumber()` 결과를 `_requestedPhoneNumber`에 저장한다.
   - 전화번호 입력 변경 감지는 표시값과 API 정규화값을 비교하도록 정리한다.

2. 사용자 프로필 응답 계약 반영
   - `UserProfile.phoneNumber`는 제거한다.
   - `phoneNumberMasked`, `phoneVerifiedAt`, `phoneVerified`를 optional/기본값 안전하게 파싱한다.
   - 개인정보 화면은 원문 전화번호에 의존하지 않는다.

3. 프로필 이미지 변경
   - `image_picker`로 단일 이미지를 선택한다.
   - 새 이미지가 있으면 `PATCH /api/users/me`를 multipart로 호출한다.
   - multipart field는 `nickname`, `gender`, `birthDate`, file field는 `profileImage`를 사용한다.
   - 새 이미지가 없으면 기존 JSON 요청을 유지한다.
   - 삭제/초기화 버튼은 제공하지 않는다.

4. 프로필 이미지 표시
   - `/uploads/user-profile-images/...` 같은 상대경로는 `resolveApiUrl()`로 변환한다.
   - 마이페이지, 여행/정산 참여자 아바타 등 사용자 프로필 이미지 표시 지점을 점검한다.

5. refresh token rotation
   - refresh API 응답의 새 access token과 refresh token 저장은 기존 동작을 유지한다.
   - 인증된 API 요청에서 401이 발생하면 refresh 후 원 요청을 1회 재시도하는 구조를 검토해 적용한다.
   - refresh 실패 시 저장 토큰을 정리하고 로그인 필요 상태로 흐르게 한다.

## 테스트 계획

- `PhoneVerificationCodeSent`가 `phoneNumber` 없는 응답을 파싱하는지 확인한다.
- 전화번호 인증 요청 후 확인 요청에 앱이 저장한 정규화 전화번호가 전달되는지 위젯 테스트로 확인한다.
- `UserProfile`이 `phoneNumberMasked`, `phoneVerified`, `phoneVerifiedAt` 응답을 파싱하는지 확인한다.
- 프로필 이미지가 선택된 경우 multipart 요청의 field와 file field가 서버 계약과 맞는지 서비스 테스트로 확인한다.
- 프로필 이미지가 선택되지 않은 경우 기존 JSON `PATCH /api/users/me` 경로가 유지되는지 확인한다.
- refresh token rotation 및 401 재시도 흐름은 API 클라이언트 테스트로 확인한다.
- 최종 검증으로 `flutter analyze`, `flutter test`를 실행한다.

## 위험과 확인 사항

- refresh 자동 재시도는 `ApiClient`와 `AuthService` 사이 순환 의존이 생기기 쉬우므로 작은 범위의 token refresh coordinator 또는 호출부 패턴을 검토한다.
- multipart PATCH는 서버가 `multipart(HttpMethod.PATCH, "/api/users/me")`를 지원하므로 앱도 method를 `PATCH`로 유지한다.
- 서버 프로필 이미지 allowlist 정책상 앱에서 임의 외부 URL 입력은 제공하지 않는다.
- 이미지 삭제/초기화는 API 계약이 확정되지 않았고 사용자 확인에 따라 제외한다.
- 개인정보, 인증 토큰, 프로필 이미지는 보안 검토 대상으로 본다.
