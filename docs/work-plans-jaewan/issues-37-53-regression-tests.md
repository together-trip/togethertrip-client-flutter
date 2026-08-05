# 이슈 #37·#53 회귀 테스트 보강 계획

## 연결 이슈

- App #37: Firebase 푸시 수신·클릭과 딥링크 이동
- App #53: iOS Sign in with Apple 로그인 예외 처리

## 목표

- Firebase 정적 메시징 API에 묶인 푸시 핸들러를 최소한의 gateway 경계로 감싸 수명주기를 자동 검증한다.
- foreground, background 클릭, 종료 상태 초기 메시지가 기존과 같은 읽음 처리와 화면 이동을 수행하는지 보장한다.
- Apple 로그인 취소와 credential revoked 상태에서 오류 안내와 버튼 상태가 의도대로 복구되는지 보장한다.

## 범위

1. 푸시 메시징 경계
   - `NotificationMessagingGateway`를 추가해 Firebase 초기화, background handler 등록, foreground/opened stream, initial message 조회를 감싼다.
   - production adapter를 기본값으로 사용해 기존 앱 동작을 유지한다.
   - route factory를 선택적으로 주입할 수 있게 해 실제 화면의 네트워크 로딩 없이 navigation 계약을 검증한다.
2. 푸시 수명주기 테스트
   - foreground Snackbar의 `열기`가 읽음 처리 후 route를 연다.
   - opened stream과 initial message가 route를 연다.
   - 읽음 처리 실패가 navigation을 막지 않는다.
   - 잘못된 deeplink는 아무 동작도 하지 않는다.
   - dispose 이후 메시지는 처리하지 않는다.
3. Apple 예외 테스트
   - 사용자가 취소하면 오류 문구를 노출하지 않고 버튼을 다시 사용할 수 있다.
   - revoked credential은 정확한 안내를 표시하고 버튼을 다시 사용할 수 있다.

## 제외 범위

- 푸시 UX, deeplink 대상, 읽음 정책 변경
- Firebase·APNs 운영 설정과 실제 기기 E2E
- Apple 로그인 API, nonce, 계정 삭제 동작 변경
- 화면 디자인과 사용자 문구 변경

## 커밋 계획

1. 이 계획 문서를 독립 커밋한다.
2. Firebase messaging gateway와 route factory seam을 추가한다.
3. 푸시 메시지 수명주기 회귀 테스트를 추가한다.
4. Apple 취소·revoked widget test를 추가한다.
5. review와 verification 문서를 추가한다.

## 검증 계획

- `flutter test test/features/notification/service/notification_push_message_handler_test.dart`
- `flutter test test/widget_test.dart`
- `flutter analyze`
- `flutter test`
- `dart run tool/verify_release_config.dart --platform-only`

