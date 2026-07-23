# Issue 10 범위 분할

## 대상 이슈

- GitHub Issue: #10 `feat: 여행 상세 게시판 CRUD 및 소비 등록 화면 구현`
- 브랜치: `feature/issue-10-trip-board-expense`
- 담당 owner: `jaewan`

## 참고 자료

- 전역 와이어프레임: `docs/togethertrip_wireframes.html`
  - 여행 페이지 피드/빈 상태: 섹션 4
  - 기록/소비 등록 선택 및 소비 등록 폼: 섹션 5
  - 댓글/결제 정보 바텀시트: 섹션 6
- 전역 API 문서: `docs/api-spec.md`
  - Post API
  - Transaction API
- 현재 앱 구조:
  - `lib/features/trip/screen/trip_detail_screen.dart`
  - `lib/features/trip/service/trip_service.dart`
  - `lib/core/network/api_client.dart`

## 범위 분할

### 1. 여행 상세 피드 및 게시글 CRUD

목표:

- 여행 상세 페이지를 와이어프레임의 여행 피드 구조로 확장한다.
- 전체/#기록/#소비 탭, 피드 목록, 빈 상태, FAB 진입점을 만든다.
- 별도 상세 화면 없이 피드 카드 안에서 게시글 표시/본문 확장/수정/삭제를 처리한다.
- 게시글 목록/작성/수정/삭제 기본 CRUD를 연결한다.
- 게시글 첨부 파일을 카드에 표시한다.
- 소비 게시글은 거래 상세 보강 조회로 원 통화 금액을 표시한다.
- 기존 여행 상세 정보/수정/삭제는 정보 바텀시트로 이동한다.

계획 문서:

- `docs/work-plans-jaewan/issue-10-trip-board-crud.md`

주요 API:

- `GET /api/trips/{tripId}/posts`
- `POST /api/trips/{tripId}/posts`
- `GET /api/trips/{tripId}/posts/{postId}`
- `PATCH /api/trips/{tripId}/posts/{postId}`
- `DELETE /api/trips/{tripId}/posts/{postId}`

### 2. 댓글 목록/작성/삭제

목표:

- 게시글 상세 또는 피드 카드에서 댓글 바텀시트를 연다.
- 댓글 목록, 작성, 삭제를 지원한다.
- 대댓글은 #10 제외 범위로 두고 원댓글만 처리한다.

계획 문서:

- `docs/work-plans-jaewan/issue-10-comments.md`

주요 API:

- `GET /api/trips/{tripId}/posts/{postId}/comments`
- `POST /api/trips/{tripId}/posts/{postId}/comments`
- `DELETE /api/trips/{tripId}/posts/{postId}/comments/{commentId}`

### 3. 소비 등록

목표:

- FAB 선택 바텀시트에서 소비 등록 화면으로 진입한다.
- 금액/통화/결제자/부담자/제목/카테고리/내용을 입력한다.
- 등록 성공 시 거래를 생성하고, 필요하면 소비형 게시글 표시를 갱신한다.

계획 문서:

- `docs/work-plans-jaewan/issue-10-expense-registration.md`

주요 API:

- `POST /api/trips/{tripId}/transactions`
- `GET /api/trips/{tripId}`의 `participants`

## 추천 구현 순서

1. 게시글/댓글/거래 모델과 서비스 메서드를 먼저 만든다.
2. 여행 상세 화면을 피드형 레이아웃으로 전환하고 정보 바텀시트를 분리한다.
3. 고정 탭과 피드 목록/추가 로딩/새로고침을 붙인다.
4. 피드 카드 기반 게시글 작성/수정/삭제를 붙인다.
5. 첨부 carousel과 거래 금액 보강 조회를 붙인다.
6. 댓글 바텀시트를 붙인다.
7. 소비 등록 폼을 붙인다.
8. 통합 새로고침, 오류/빈 상태, widget/unit 테스트를 정리한다.

## 공통 결정사항

- 여행 상세는 AppBar, 여행 요약 헤더, 정산 바, 고정 탭, 스크롤 피드 구조로 전환한다.
- 정산 바는 표시만 하고 클릭 시 준비 중 스낵바를 보여준다.
- 기존 여행 상태/국가/참여자 정보와 방장용 수정/삭제는 정보 바텀시트로 이동한다.
- 알림/정보/더보기/댓글/소비 아이콘은 Material outline 계열을 사용한다.
- 스타일은 기존 앱의 흰 배경, 검정 텍스트, 얇은 border 톤을 유지한다.
- 게시글 첨부 파일은 피드 카드 표시만 포함한다.
- 작성/수정 첨부 입력은 이번 프론트 범위에서 제외하고, 파일 저장소 업로드, 업로드 URL 발급, 첨부 수정 API가 확정된 뒤 별도 범위로 둔다.
- 첨부는 인스타그램식 carousel로 표시한다.
- 목록 응답에 첨부가 있으면 그대로 사용하고, 없으면 상세 보강 조회로 채운다.
- 게시글 상세 화면은 만들지 않는다. 피드 카드에서 본문 더보기, 첨부 미리보기, 수정/삭제 메뉴, 댓글 진입을 처리한다.
- 카드 자체 탭은 동작하지 않는다.
- 댓글 변경 후 피드는 첫 페이지를 재조회해 `commentCount`를 서버 기준으로 갱신한다.
- 소비 게시글 삭제와 연결 거래 무효 처리는 백엔드 Issue #55 보강 후 프론트에서 일반 게시글 삭제와 같은 흐름으로 호출한다.
- 소비 게시글 금액은 `transactionId` 기반 거래 상세 보강 조회로 표시한다.
- 지도/위치 선택 고도화는 제외하되, `placeName`, `latitude`, `longitude` 필드는 모델에 포함해 확장 가능하게 둔다.
- 프론트 1차는 `placeName`만 전송하고 `latitude`, `longitude`는 전송하지 않는다.
- 게시글 수정의 날짜/위치 저장은 백엔드 Issue #55의 `UpdatePostRequest` 보강을 전제로 한다.
- 게시글 작성/수정 날짜는 필수이며, 선택 날짜의 KST 정오를 UTC ISO timestamp로 변환해 `occurredAt`으로 전송한다.
- 게시글 작성/수정 위치는 선택이며, `placeName`만 전송한다.
- 게시글 작성/수정 내용은 선택이다.
- 카테고리는 `관광`, `식비`, `교통`, `숙박`, `쇼핑`, `기타` 칩을 사용하고, `기타`는 직접 입력 필수다. 이모지는 사용하지 않는다.
- 작성/수정은 와이어프레임처럼 상단 여백이 남는 큰 바텀시트로 연다.
- `...` 메뉴는 작성자에게만 노출하고, 내 participant 조회 실패 시 숨긴다.
- `...` 메뉴는 하단 액션시트로 열고 삭제는 확인 다이얼로그를 거친다.
- 대댓글은 제외한다. 서버 응답의 `commentDepth`가 있어도 UI는 원댓글 목록 기준으로 처리한다.
- 정산 시작 이후 소비 수정 제한은 백엔드 오류 메시지를 표시하는 수준으로 두고, 선제 차단은 별도 이슈로 미룬다.
- 금액 입력은 1차로 숫자 직접 입력 + 참여자별 금액 직접/균등 분배까지 지원한다.
- 빈 상태, 오류 상태, 로딩 상태는 탭/상황별로 분리한다.

## 남은 질문

- 소비 등록 후 `POST /posts`를 별도로 호출해 소비형 게시글을 만들어야 하는지, 서버에서 거래 기반 게시글이 자동 생성되는지 확인이 필요하다.
- 소비 등록의 기본 통화 후보는 여행 기본 통화 + KRW + USD 정도로 충분한지 확인이 필요하다.
