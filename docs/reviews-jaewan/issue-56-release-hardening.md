# 이슈 #56 출시 설정 하드닝 리뷰

## 요약

- Code Reviewer 기준의 차단 발견 사항은 없다.
- Flutter UI Reviewer 기준으로 기존 `MyMenuRow`, `PublicSiteLinks`, `ExternalLinkLauncher` 구조를 재사용했으며 화면에서 API를 직접 호출하지 않는다.
- API endpoint, DTO, 인증 헤더 계약은 변경하지 않아 API Contract Reviewer의 교차 저장소 수정 대상은 없다.
- release 비밀값은 저장소에 추가하지 않았고 예시 파일은 placeholder 상태로 검증을 통과하지 못하게 했다.

## 발견 사항

| 심각도 | 파일 | 내용 | 제안 |
| --- | --- | --- | --- |
| 없음 | - | 자동 검증 범위에서 수정이 필요한 버그를 찾지 못했다. | 실제 signing과 스토어 콘솔 검증을 완료한다. |

## Flutter UI 수동 확인 체크리스트

- 선택된 UI안만 구현되었는가: 기존 마이 메뉴 패턴으로 요청된 진입점만 추가함
- mock 데이터로 화면이 동작하는가: 주입한 `AuthService`, `PublicSiteLinks`, launcher로 widget test 통과
- 화면 파일과 위젯 파일 책임이 분리되었는가: 기존 구조 유지
- API 연동 지점이 repository/interface 형태로 분리되었는가: 공개 URL launcher interface 재사용
- screen에서 HTTP 호출을 직접 하지 않는가: 직접 호출 없음
- 기존 프로젝트 구조를 유지했는가: 유지
- 한국어 UI가 자연스러운가: `계정 삭제 안내` 사용
- 한 손 조작이 가능한가: 기존 메뉴 row와 동일
- 입력 단계가 과도하지 않은가: 입력 단계 없음
- 정산 개념이 어렵게 노출되지 않는가: 관련 없음
- 로딩 상태가 있는가: 기존 프로필 로딩 유지
- 빈 상태가 있는가: 관련 없음
- 오류 상태가 있는가: 링크 실행 실패 오류와 SnackBar 유지
- 작은 화면에서 텍스트가 겹칠 위험이 없는가: 기존 단일 행 메뉴 컴포넌트 사용
- 구현하지 말아야 할 요소가 제외되었는가: 신규 알림 설정 기능을 만들지 않고 미완성 메뉴 제거

## 확인한 명령

```bash
flutter analyze
flutter test
flutter test test/features/my/account_deletion_screen_test.dart
flutter test test/tool/release_config_validator_test.dart
dart run tool/verify_release_config.dart --platform-only
./gradlew :app:processDebugMainManifest
plutil -lint ios/Runner/Runner.entitlements ios/Runner/RunnerRelease.entitlements ios/Runner/PrivacyInfo.xcprivacy
xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Release -showBuildSettings
```

## 남은 위험

- 실제 키로 서명한 AAB와 iOS Archive는 만들지 않았다.
- 실제 기기의 계정 삭제, APNs, Kakao/Apple 로그인 E2E는 수행하지 않았다.
- App Store Privacy/Google Data Safety 선언은 운영 담당자가 실제 데이터 처리와 최종 대조해야 한다.
