# 이슈 #37·#53 회귀 테스트 보강 검증

## 검증 대상

- `NotificationMessagingGateway` production adapter와 background handler 등록
- foreground Snackbar 열기, opened stream, initial message navigation
- 알림 읽음 실패, 잘못된 deeplink, dispose 이후 메시지 처리
- Apple 로그인 취소·credential revoked 오류와 버튼 상태 복구
- 기존 앱 전체 회귀와 release 플랫폼 설정

## 실행 명령과 결과

### 정적 분석

```bash
flutter analyze
```

- 성공, issue 0개

### 푸시 수명주기 targeted test

```bash
flutter test \
  test/features/notification/service/notification_push_message_handler_test.dart \
  --timeout 30s
```

- 성공, 6개 테스트 통과
- foreground/opened/initial, 읽음 실패, invalid deeplink, dispose 구독 해제 확인
- fake controller는 synchronous broadcast로 이벤트를 전달하고 handler dispose 뒤 controller를 닫아 정상 종료 확인
- production background handler가 gateway 초기화에 전달되는 계약 확인

### #37·#53 targeted test

```bash
flutter test \
  test/features/notification/service/notification_push_message_handler_test.dart \
  test/widget_test.dart \
  --timeout 30s
```

- 성공, 21개 테스트 통과
- Apple happy path, 취소 후 무오류·재시도, revoked 안내·버튼 복구 확인

### 전체 회귀 테스트

```bash
flutter test --timeout 30s
```

- 성공, 217개 테스트 통과

### release 플랫폼 설정

```bash
dart run tool/verify_release_config.dart --platform-only
```

- 성공, `Release 설정 정적 검증을 통과했습니다.`

### Git 검사

```bash
git diff --check
```

- whitespace 오류 없음

## 미검증 항목

- 실제 FCM/APNs 수신과 push notification 클릭
- 실제 Apple ID authorization sheet와 credential revoke
- signed Android AAB, iOS Archive와 스토어 테스트 트랙
