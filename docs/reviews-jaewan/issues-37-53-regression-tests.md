# 이슈 #37·#53 회귀 테스트 보강 리뷰

## 요약

- 푸시 메시지 처리의 production 동작은 유지하고 Firebase 정적 API만 gateway 뒤로 이동했다.
- 기본 adapter는 기존과 동일하게 Firebase 앱 초기화, background handler 등록, foreground/opened stream 구독, initial message 조회를 수행한다.
- route factory는 테스트에서만 대체하며 production 기본 route는 기존 `TripDetailScreen`과 `TripRecapScreen`을 그대로 생성한다.
- Apple 로그인 production 코드는 변경하지 않고 기존 `AuthService` 주입 경계만 사용해 예외 상태를 검증했다.

## 역할별 확인

### Architect

- `NotificationMessagingGateway`는 외부 Firebase SDK 정적 상태만 격리한다.
- 핸들러의 payload 파싱, 읽음 처리, navigation 정책은 기존 책임에 남겼다.
- 새로운 전역 상태나 service locator를 추가하지 않았다.

### Code Reviewer

- background callback의 `@pragma('vm:entry-point')`와 Firebase 등록 계약이 유지된다.
- gateway 초기화 실패 시 `_initialized`를 되돌리는 기존 재시도 동작이 유지된다.
- 읽음 API 실패가 navigation을 막지 않는 기존 예외 정책이 유지된다.
- handler dispose 이후 두 stream 구독이 해제되고 이후 이벤트가 처리되지 않음을 검증한다.
- 차단 발견 사항은 없다.

### Flutter UI Reviewer

- foreground SnackBar 제목·본문·`열기` 문구를 변경하지 않았다.
- Apple 취소 시 오류를 표시하지 않고 revoked 시 기존 한국어 안내를 그대로 표시한다.
- 로그인 버튼의 로딩·비활성·복구 동작 외 UI 변경은 없다.

### API Contract Reviewer

- notification 읽음 API, Apple 로그인 API, DTO와 인증 헤더는 변경하지 않았다.
- 서버 저장소 변경 대상은 없다.

## 남은 외부 검증

- 운영 Firebase/APNs 설정을 사용한 Android·iOS 실제 기기 foreground/background/terminated 푸시
- Apple sandbox 실제 기기의 취소, revoked credential, 재승인과 탈퇴 revoke
