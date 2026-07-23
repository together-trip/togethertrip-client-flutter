# 정산 이후 소비 관련 프론트 액션 제한 검증

- GitHub Issue: https://github.com/together-trip/togethertrip-client-flutter/issues/23
- 작업 브랜치: `fix/issue-23-settlement-expense-ui-lock`
- 검증일: 2026-06-19

## 루프 선택

- 선택 루프: Flutter 구현 루프
- 하위 루프: Planner -> UI Controller -> TDD Guide -> Implementation -> Flutter UI Reviewer -> E2E Test -> Verify Agent
- 선택 이유: 여행 상세 화면의 소비 등록/수정/삭제 액션을 정산 상태에 맞춰 제한하는 사용자 흐름 변경이다.

## 점수 루프

| 루프 | 점수 | 기준 | 결과 |
| --- | ---: | --- | --- |
| Planner | 5/5 | client-flutter #23 범위에 맞게 프론트 액션 제한으로 한정 | 통과 |
| UI Controller | 5/5 | 숨김보다 disabled + 안내 문구로 사용자 이해 비용을 낮춤 | 통과 |
| TDD Guide | 5/5 | 정산 완료 소비 등록 차단, 소비 게시글 액션 차단, 기록 액션 유지 테스트 추가 | 통과 |
| Flutter UI Reviewer | 4/5 | 기존 `TripDetailScreen` 구조 유지. 액션 tile 분리는 후속 정리 여지 있음 | 통과 |
| E2E Test | 4/5 | 위젯 테스트로 핵심 흐름 검증. 실제 기기 수동 확인은 미실행 | 통과 |
| Verify Agent | 5/5 | `flutter analyze`, `flutter test` 통과 | 통과 |

통과 기준은 평균 4점 이상이고, Verify 5점이다. 현재 평균 4.67점으로 통과한다.

## 변경 요약

- 정산 완료 여행에서 소비 등록 선택지를 비활성화하고 안내 문구를 표시한다.
- 정산 완료 여행에서 `EXPENSE` 게시글의 수정/삭제 액션을 비활성화한다.
- 정산 완료 여행에서도 일반 `RECORD` 게시글 수정/삭제 액션은 유지한다.
- 관련 위젯 테스트를 추가했다.

## 검증 명령

```bash
flutter test test/features/trip/trip_detail_screen_test.dart
flutter analyze
flutter test
```

## 검증 결과

- `flutter test test/features/trip/trip_detail_screen_test.dart`: 성공
- `flutter analyze`: 성공
- `flutter test`: 성공

## 확인한 사용자 흐름

- `SETTLED` 여행에서 소비 등록 폼으로 진입하지 않는다.
- `SETTLED` 여행에서 기록 작성 폼은 열린다.
- `SETTLED + EXPENSE` 게시글은 수정/삭제 액션이 비활성화된다.
- `SETTLED + RECORD` 게시글은 수정/삭제 액션이 활성화된다.

## 남은 위험

- 실제 기기 또는 스크린샷 기반 수동 확인은 수행하지 않았다.
- 백엔드 #80이 병합되기 전까지는 API 직접 호출 방어는 server-main PR에 의존한다.
