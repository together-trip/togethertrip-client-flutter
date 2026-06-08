# Work Plan: 여행 API 기반 여행 화면

작성일: 2026-06-07
브랜치: `feature/issue-8-trip-api-screens`
이슈: `#8`
PR: `#9`

## 작업

Flutter 앱의 여행 탭을 placeholder 화면에서 server-main 여행 API 기반 화면으로 전환한다.
사용자가 참여한 여행 목록을 조회하고, 여행 생성/상세/수정/삭제 흐름을 1차 MVP 화면으로 연결한다.

## 배경

server-main에 `/api/trips` 기반 여행 API가 준비되었고, Flutter 앱의 여행 탭은 아직 "메인페이지 입니다."
placeholder 상태였다. 앱에서 실제 여행 목록과 생성/상세 진입이 가능해야 이후 기록/소비, 정산 화면을
여행 상세 하위 흐름으로 붙일 수 있다.

## 연동 API (gateway 경유, 기존 `/api/...` 프리픽스)

- `GET /api/trips` → 현재 사용자가 접근 가능한 여행 목록(cursor pagination)
- `POST /api/trips` → 여행 생성
- `GET /api/trips/{tripId}` → 여행 상세 조회
- `PATCH /api/trips/{tripId}` → 여행 기본 정보 수정
- `DELETE /api/trips/{tripId}` → 여행 삭제
- `PUT /api/trips/{tripId}/countries` → 여행 국가 목록 변경

## 범위

- `ApiClient.put()` 추가
- `TripService` 추가: 여행 목록/생성/상세/수정/삭제/국가 변경 API 연동
- 여행 모델 추가: `TripListPage`, `TripSummary`, `TripDetail`, `TripCountry`, `TripParticipant`,
  `TripFormInput`
- `TripListScreen`: 목록, 빈 상태, 오류 상태, 새로고침, cursor 더 보기, 여행 생성 진입
- `TripFormScreen`: 국가 선택 → 일정 선택 → 동행 추가 → 여행 제목 4단계 생성/수정 플로우
- `TripDetailScreen`: 여행 상세, 상태/국가/참여자 표시, 방장 기준 수정/삭제 액션 노출
- `MainShellScreen`의 여행 탭을 실제 여행 목록 화면으로 교체
- 로그인/회원가입 완료 후 메인 진입 경로에 `AuthService`/`TripService` 주입 경로 연결
- `ApiClient.put()` 및 `TripService` 단위 테스트 추가

## 제외 범위

- 초대 링크 생성, 참여자 제거, 방장 위임 화면
- 기록/소비, 정산, 알림 연동
- 국가/통화 선택용 외부 검색 또는 자동 환율 조회
- 사진 업로드, 지도/위치 선택
- 실서버 수동 QA 완료 체크

## 설계 결정

- 현재 Flutter 앱 구조가 단순한 feature-first 구조이므로 별도 상태관리 패키지를 추가하지 않고
  `TripService`와 화면 로컬 state로 구현한다.
- API 호출은 기존 `AuthService` 패턴과 맞춰 `ApiClient` + access token 조합으로 처리한다.
- 여행 상세의 수정/삭제 액션은 서버 권한 실패에만 기대지 않고, 현재 사용자 조회(`getMe`) 결과와
  `ownerUserId`를 비교해 방장에게만 노출한다.
- 여행 수정 화면은 생성 화면(`TripFormScreen`)을 재사용한다. 단, 참여자 편집은 이번 범위에서 제외하고
  기본 정보와 국가 목록 변경만 처리한다.
- 목록은 서버 cursor 응답(`nextCursor`, `hasNext`)에 맞춰 첫 페이지 조회와 "더 보기" 버튼을 제공한다.
- 여행 생성 화면은 제공된 와이어프레임 기준으로 4단계 wizard UX를 적용한다. API 요청은 기존 여행 API DTO에
  맞춰 선택 국가, 날짜, 동행자, 제목을 마지막 단계에서 한 번에 전송한다.
- 생성 화면의 기본 통화는 선택된 첫 국가 기준으로 자동 지정한다. 현재는 일본은 `JPY`, 그 외 국가는 `KRW`로
  보낸다.

## 변경 파일

- `lib/core/network/api_client.dart` - `put()` 추가
- `lib/features/trip/service/trip_service.dart` - 여행 API 서비스와 모델
- `lib/features/trip/screen/trip_list_screen.dart` - 여행 목록 화면
- `lib/features/trip/screen/trip_form_screen.dart` - 여행 생성/수정 화면
- `lib/features/trip/screen/trip_detail_screen.dart` - 여행 상세 화면
- `lib/features/main/screen/main_shell_screen.dart` - 여행 탭 화면 교체 및 service 주입
- `lib/features/auth/screen/onboarding_screen.dart` - 메인 진입 시 service 주입 전달
- `lib/features/auth/screen/sign_up_profile_screen.dart` - 회원가입 완료 후 메인 진입 시 service 주입 전달
- `lib/main.dart` - 테스트/앱 진입용 `TripService` 주입 경로 추가
- `test/core/network/api_client_test.dart` - `put()` 테스트
- `test/features/trip/service/trip_service_test.dart` - 여행 목록/생성 서비스 테스트
- `test/widget_test.dart` - 새 여행 탭 진입 기준으로 기존 기대값 조정

## 테스트 계획

```bash
flutter analyze
flutter test
git diff --check
```

수동 확인:
- 여행 목록 조회와 빈 목록 상태 확인
- 여행 생성 후 목록 반영 및 상세 진입 확인
- 여행 상세에서 국가/참여자 표시 확인
- 방장 계정에서 수정/삭제 액션 노출 및 처리 확인
- 일반 참여자 계정에서 수정/삭제 액션 미노출 확인

검증 결과:
- `flutter analyze`: 통과
- `flutter test`: 통과
- `git diff --check`: 통과

## 위험과 확인 사항

- `TripFormScreen`의 생성 UX는 국가/일정/동행/제목 4단계로 분리했다. 국가는 와이어프레임처럼 복수 선택을
  지원하며, 선택 순서에 맞춰 서버의 countries list DTO로 전송한다.
- 여행 수정에서 동행자 편집은 제외했다. 초대/제거/방장 위임 API 화면이 들어올 때 별도 작업으로 분리한다.
- 현재 날짜 입력은 `yyyy-MM-dd` 텍스트 입력이다. 날짜 선택 캘린더는 후속 UX 개선으로 다룬다.
- PR 커밋에는 기존 로컬 iOS 설정 변경(`.metadata`, `ios/Flutter/*`, `ios/Runner/Info.plist`)을 포함하지 않았다.

---

# GitHub 이슈 문서 (work-item 템플릿)

> 제목: `feat: 여행 API 기반 여행 화면 구현`

## 배경

server-main의 여행 API가 준비되어 Flutter 앱의 여행 탭을 실제 API 기준 화면으로 전환합니다.
현재 여행 탭은 placeholder 상태이므로, 사용자가 참여한 여행 목록을 보고 새 여행을 만들며 상세 정보를
확인할 수 있는 1차 화면이 필요합니다.

## 구현 범위

- [x] 여행 API 모델 추가: 여행 목록, 상세, 국가, 참여자 응답 모델
- [x] TripService 추가: `GET /api/trips`, `POST /api/trips`, `GET /api/trips/{tripId}`,
  `PATCH /api/trips/{tripId}`, `DELETE /api/trips/{tripId}`, `PUT /api/trips/{tripId}/countries`
- [x] 여행 탭을 placeholder에서 실제 목록 화면으로 교체
- [x] 여행 생성 화면 구현: 여행명, 기본 통화, 여행 기간, 국가, 동행자 입력
- [x] 여행 상세 화면 구현: 기본 정보, 국가, 참여자 목록 표시
- [x] 여행 수정/삭제 흐름 구현: 방장 기준 수정 진입, 삭제 확인 다이얼로그
- [x] cursor 기반 목록 조회와 새로고침/빈 상태/오류 상태 처리
- [x] API 클라이언트에 필요한 `put` 메서드 추가

## 제외 범위

- 초대 링크 생성/참여자 제거/방장 위임 화면
- 기록/소비, 정산, 알림 연동
- 국가/통화 선택용 외부 검색 또는 자동 환율 조회
- 사진 업로드 및 지도/위치 선택

## 작업 계획

1. 서버 여행 API 요청/응답 DTO를 Flutter 모델과 서비스로 매핑합니다.
2. 여행 탭 목록 화면을 구성하고 목록 조회, cursor 추가 로딩, 새로고침을 연결합니다.
3. 여행 생성 화면을 만들고 생성 성공 시 목록/상세로 반영합니다.
4. 상세 화면과 수정/삭제 흐름을 연결합니다.
5. widget/unit 테스트를 추가하고 `flutter analyze`, `flutter test`로 검증합니다.

## 검증 방법

- [x] `flutter analyze`
- [x] `flutter test`
- [ ] 수동: 여행 목록 조회, 빈 목록 상태, 여행 생성 후 목록 반영
- [ ] 수동: 여행 상세 진입, 국가/참여자 표시, 수정/삭제 후 화면 반영

## 완료 기준

- [x] 여행 탭에서 실제 API 기반 목록/생성/상세/수정/삭제 흐름을 사용할 수 있습니다.
- [x] API 실패/빈 상태/로딩 상태가 화면에서 깨지지 않습니다.
- [x] 구현 범위 항목 반영 및 검증 통과
- [ ] `develop` 대상 PR 머지

## 참고 자료

- 이슈: `#8`
- PR: `#9`
- 작업 계획: `docs/work-plans-donghyun/trip-api-screens.md`
- 연동 API: main `TripController` (`/api/trips`)

---

# 커밋 메시지

```text
feat: 여행 API 기반 여행 화면 구현
```

---

# PR

- base: `develop` ← head: `feature/issue-8-trip-api-screens`
- 제목: `feat: 여행 API 기반 여행 화면 구현`
- 본문:

```text
## 개요
여행 탭을 placeholder에서 실제 여행 API 기반 화면으로 전환합니다.
사용자가 참여한 여행 목록을 조회하고, 여행 생성/상세/수정/삭제 흐름을 사용할 수 있도록 구현했습니다.

Closes #8

## 변경 사항
- ApiClient: PUT 메서드 추가
- TripService: 여행 목록/생성/상세/수정/삭제/국가 변경 API 연동 및 모델 추가
- TripListScreen: 여행 목록, 빈 상태, 오류 상태, cursor 더 보기, 새로고침
- TripFormScreen: 여행 생성/수정 입력 화면
- TripDetailScreen: 여행 상세, 국가/참여자 표시, 방장 기준 수정/삭제 액션 노출
- 로그인/회원가입 완료 후 MainShellScreen에 AuthService/TripService 주입 경로 연결

## 연동 API
- GET /api/trips
- POST /api/trips
- GET /api/trips/{tripId}
- PATCH /api/trips/{tripId}
- DELETE /api/trips/{tripId}
- PUT /api/trips/{tripId}/countries

## 검증
- flutter analyze
- flutter test
- git diff --check

## 참고
- 기존 로컬 iOS 설정 변경은 커밋에 포함하지 않았습니다.
```
