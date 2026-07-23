# Issue 10 구현 계획: 여행 상세 피드 및 게시글 CRUD

## 임무

여행 상세 페이지에서 기본 게시판 흐름을 사용할 수 있게 한다. 와이어프레임의 여행 페이지 피드/빈 상태를 기준으로 전체/#기록/#소비 탭, 피드 카드, 게시글 작성/수정/삭제를 구현한다. 별도 게시글 상세 화면은 만들지 않고, 인스타그램 피드처럼 카드 안에서 본문/첨부/댓글 진입을 처리한다.

## 범위

- `PostService`와 게시글 모델 추가
- 여행 상세 화면에 피드 영역 추가
- 전체/#기록/#소비 필터 탭 추가
- 게시글 목록 cursor 조회와 새로고침/추가 로딩
- 게시글 작성 화면
- 게시글 수정 화면
- 게시글 첨부 파일 표시
- 게시글 삭제 확인 다이얼로그
- 작성/수정/삭제 후 목록 갱신

## 제외 범위

- 댓글 작성/삭제 세부 구현은 `issue-10-comments.md`
- 소비 등록 폼은 `issue-10-expense-registration.md`
- 파일 저장소 업로드, 업로드 URL 발급, 이미지 리사이징
- 지도/위치 선택 고도화
- 정산 플로우

## 참고

- 와이어프레임:
  - 여행 페이지 피드: `docs/togethertrip_wireframes.html` 섹션 4
  - 기록/소비 등록 선택: `docs/togethertrip_wireframes.html` 섹션 5
  - 댓글 바텀시트와 결제 정보: `docs/togethertrip_wireframes.html` 섹션 6
- API:
  - `GET /api/trips/{tripId}/posts`
  - `POST /api/trips/{tripId}/posts`
  - `GET /api/trips/{tripId}/posts/{postId}`
  - `PATCH /api/trips/{tripId}/posts/{postId}`
  - `DELETE /api/trips/{tripId}/posts/{postId}`
  - `GET /api/trips/{tripId}/transactions/{transactionId}`
  - `GET /api/users/me/trip-participants?tripId={tripId}`

## 설계

### 파일 구성

- `lib/features/post/service/post_service.dart`
- `lib/features/post/screen/post_form_screen.dart`
- 필요 시 `lib/features/post/widget/post_feed_card.dart`
- 필요 시 `lib/features/post/widget/post_attachment_preview.dart`
- 필요 시 `lib/features/post/widget/post_attachment_carousel.dart`
- 필요 시 `lib/features/post/widget/post_action_sheet.dart`
- 소비 금액 보강 조회는 `lib/features/transaction/service/transaction_service.dart`를 사용한다.
- 테스트:
  - `test/features/post/service/post_service_test.dart`
  - 필요 시 `test/features/post/screen/post_*_test.dart`
  - 필요 시 `test/features/transaction/service/transaction_service_test.dart`

### 모델

- `PostListPage`
  - `items`, `size`, `nextCursor`, `hasNext`
- `PostSummary`
  - API 문서의 `PostSummaryResponse` 필드 반영
- `PostDetail`
  - API 문서의 `PostDetailResponse` 필드 반영
  - 별도 상세 화면용이 아니라 피드 카드 첨부 보강 조회와 수정 폼 초기값 용도로 사용한다.
- `PostAttachment`
  - `id`, `attachmentType`, `fileUrl`, `thumbnailUrl`, `fileSize`, `mimeType`, `sortOrder`
  - 게시글 카드에서는 상세 보강 조회로 받은 첨부를 표시한다.
- `PostFormInput`
  - `transactionId`, `title`, `category`, `content`, `postType`, `occurredAt`, `placeName`, `latitude`, `longitude`
- `TransactionDetail`
  - 소비 카드 금액 보강 조회용. `summary.amount`, `summary.currency`를 카드 금액 표시에 사용한다.
- `MyTripParticipant`
  - 작성자 메뉴 노출 판단용. `GET /api/users/me/trip-participants?tripId={tripId}` 응답의 `id`를 `currentParticipantId`로 보관한다.

### 화면 흐름

1. `TripDetailScreen`을 와이어프레임의 여행 피드 화면으로 전환한다.
2. `PostService.getPosts(tripId, postType, cursor, size)`로 목록을 가져온다.
3. 탭 선택 시 `postType`을 다음처럼 매핑한다.
   - 전체: query 없음
   - #기록: `RECORD`
   - #소비: `EXPENSE`
4. 상세 화면은 만들지 않고, 피드 카드 안에서 본문 더보기와 첨부 미리보기를 제공한다.
5. 목록 응답에는 첨부가 없으므로 카드별 `GET /posts/{postId}` 보강 조회로 첨부를 채운다.
6. 보강 조회 실패 시 피드 전체는 유지하고 해당 카드의 첨부 영역만 생략한다.
7. FAB 탭 시 등록 선택 바텀시트를 연다.
8. 기록 선택 시 `PostFormScreen` 작성 모드로 이동한다.
9. 작성/수정 화면은 공용으로 사용하고, 카드 `...` 메뉴에서 수정/삭제를 제공한다.
10. 수정/삭제 성공 시 목록을 갱신한다.

### 여행 피드 레이아웃

- AppBar 제목은 여행명으로 표시한다.
- AppBar 우측 아이콘은 Material outline 계열을 사용한다.
  - 알림: `Icons.notifications_none`
  - 정보: `Icons.info_outline`
- 알림 아이콘은 기존 `NotificationListScreen`으로 이동한다. 여행별 알림 필터는 제외한다.
- 정보 아이콘은 여행 정보 바텀시트를 연다.
- 여행 요약 헤더에는 기간과 국가 요약을 표시한다.
- 정산 바는 `settlementStatus` 라벨을 표시하고, 클릭 시 “정산 기능은 준비 중입니다.” 스낵바를 보여준다.
- 고정 영역은 AppBar, 여행 요약 헤더, 정산 바, 탭이다.
- 피드 영역만 스크롤한다.
- 피드 `RefreshIndicator`는 현재 탭 첫 페이지와 여행 상세 정보를 함께 갱신한다.
- 추가 로딩은 스크롤 끝 200px 전 자동 호출한다.

### 여행 정보 바텀시트

- 정보 버튼 클릭 시 `여행 정보` 바텀시트를 연다.
- 내용 높이만큼 표시하되 최대 화면 높이의 약 80%까지 허용한다.
- 국가/참여자 목록이 길면 내부 스크롤한다.
- 기존 상세 화면의 상태, 정산 상태, 국가, 참여자 정보를 이 바텀시트로 이동한다.
- 방장에게만 여행 수정/삭제 버튼을 표시한다.
- 여행 수정 성공 시 헤더와 정보 바텀시트를 갱신한다.
- 여행 삭제 성공 시 이전 여행 목록으로 pop한다.

### 피드 카드 동작

- 카드 자체 탭은 동작하지 않는다.
- 본문 `...더 보기`만 카드 안에서 본문을 확장한다.
- 댓글 아이콘/댓글 수를 누르면 댓글 바텀시트를 연다.
- 첨부 영역은 인스타그램 피드처럼 carousel로 표시한다.
  - 여러 장이면 좌우 스와이프 가능
  - `1/N` 표시
  - dot indicator 표시
  - 이미지 탭은 별도 이동 없음
  - 비디오 첨부는 썸네일이 있으면 썸네일 표시, 없으면 플레이 아이콘이 있는 placeholder 표시
- 카드 우측 `...`는 작성자에게만 노출한다.
- `...` 클릭 시 하단 액션시트를 열고 `수정`, `삭제`, `취소`를 제공한다.
- 삭제 선택 시 확인 다이얼로그를 띄운다.

### 작성/수정 바텀시트

- FAB 클릭 시 “무엇을 등록할까요?” 선택 바텀시트를 연다.
- 현재 탭에 따라 기본 강조를 다르게 둔다.
  - 전체/#기록: 기록 기본 강조
  - #소비: 소비 기본 강조
- 기록 선택 시 와이어프레임처럼 상단 여백이 남는 큰 입력 바텀시트를 연다.
- 수정도 작성과 같은 큰 입력 바텀시트 패턴으로 연다.
- 일반 route push나 완전 풀스크린은 사용하지 않는다.
- 바텀시트는 최대 화면 높이 약 90% 이하, 내부 스크롤, 키보드 대응 padding을 사용한다.
- 상단 행은 `취소 / 기록 작성·수정 / 등록·저장`으로 구성한다.
- 저장 중에는 등록/저장 액션을 disabled 처리한다.

### 작성/수정 입력 정책

- 필수값:
  - 제목
  - 카테고리
  - 날짜
- 선택값:
  - 내용
  - 위치
- 날짜 기본값:
  - 새 글 작성: 오늘 날짜
  - 수정: 기존 `occurredAt` 날짜
  - 기존 `occurredAt`이 null이면 오늘 날짜
- 날짜는 날짜만 선택하며, 선택 날짜의 KST 정오를 UTC ISO timestamp로 변환해 `occurredAt`으로 전송한다.
- 위치는 `placeName` 텍스트만 전송한다.
- `latitude`, `longitude`는 1차에서 전송하지 않는다.
- 카테고리 기본 칩:
  - 관광
  - 식비
  - 교통
  - 숙박
  - 쇼핑
  - 기타
- 카테고리에는 이모지를 사용하지 않는다.
- `기타` 선택 시 직접 입력을 필수로 한다.
- 내용은 선택이므로 제목/카테고리/날짜만으로 저장 가능하다.
- 작성/수정 첨부 입력은 제외한다.

### 첨부/거래 보강 조회

- `PostSummary.attachments`가 있으면 목록 응답 첨부를 그대로 사용한다.
- 목록 응답에 첨부가 없거나 비어 있으면 `GET /api/trips/{tripId}/posts/{postId}` 상세 보강 조회로 첨부를 채운다.
- 보강 조회 실패 시 피드 전체는 유지하고 해당 카드 첨부만 생략한다.
- `transactionId != null`이면 `GET /api/trips/{tripId}/transactions/{transactionId}`로 소비 금액을 보강 조회한다.
- 거래 보강 조회 성공 시 원 통화 기준 금액만 표시한다.
  - JPY: `¥8,800`
  - KRW: `₩10,000`
  - USD: `$12.50`
  - 기타: `EUR 12.50`
- `baseAmount`, `baseCurrency` 환산 표시는 1차에서 생략한다.
- 거래 보강 조회 실패 시 금액 영역만 생략한다.
- 금액은 정수면 소수점 없이, 소수점이 있으면 최대 2자리로 표시하고 천 단위 콤마를 적용한다.

### 탭/갱신 정책

- 작성 성공 시 바텀시트를 닫고 피드 첫 페이지를 재조회한다.
- 기본은 현재 탭을 유지한다.
- 새 글 타입이 현재 탭에 보이지 않으면 전체 탭으로 이동한다.
  - 전체에서 기록 작성: 전체 유지
  - #기록에서 기록 작성: #기록 유지
  - #소비에서 기록 작성: 전체로 이동
- 수정 성공 시 현재 탭을 유지하고 피드 첫 페이지를 재조회한다.
- 삭제 성공 시 현재 탭을 유지하고 피드 첫 페이지를 재조회한다.
- 댓글 작성/삭제 성공 후 댓글 바텀시트가 변경 여부를 반환하면 부모 피드는 첫 페이지를 재조회한다.

### 상태 표시

- 빈 상태 문구는 탭별로 다르게 표시한다.
  - 전체: `아직 기록이 없어요` / `여행의 첫 순간을 남겨보세요`
  - #기록: `아직 남긴 기록이 없어요` / `여행의 순간을 글로 남겨보세요`
  - #소비: `아직 등록한 소비가 없어요` / `여행 중 쓴 돈을 남기면 정산이 쉬워져요`
- 첫 로딩 실패와 피드가 비어 있는 상태는 전체 오류 상태와 다시 시도 버튼을 표시한다.
- 추가 로딩 실패는 스낵바로 표시한다.
- 첨부/거래 보강 조회 실패는 오류를 노출하지 않고 해당 영역만 생략한다.
- 작성/수정/삭제 실패는 스낵바 또는 폼 내부 에러로 표시한다.
- 첫 로딩은 중앙 `CircularProgressIndicator`를 사용한다.
- 추가 로딩은 리스트 하단 작은 spinner를 사용한다.
- 보강 조회는 skeleton 없이 데이터가 들어오면 영역을 자연스럽게 표시한다.

### 인터뷰 결정사항

- 별도 게시글 상세 화면은 만들지 않는다.
- 카드 본문은 `...더 보기`로 카드 안에서 확장한다.
- `RECORD`, `EXPENSE` 모두 같은 피드 카드 UI와 같은 수정/삭제 경험을 사용한다.
- 작성자에게만 `...` 메뉴를 노출한다.
- 현재 사용자 participant 조회에 실패하면 안전하게 모든 카드의 `...` 메뉴를 숨긴다.
- 작성/수정 폼은 공용 화면으로 재사용한다.
- 게시글 작성 필수값은 제목, 카테고리, 날짜다. 내용과 위치는 선택이다.
- 날짜는 실제로 `occurredAt`으로 전송한다. 작성 시 오늘 날짜를 기본값으로 두고, 수정 시 기존 `occurredAt` 날짜를 기본값으로 둔다.
- 날짜는 날짜만 선택하며, 선택 날짜의 KST 정오를 UTC ISO timestamp로 변환해 전송한다.
- 카테고리는 기본 칩을 제공하고, `기타` 선택 시 직접 입력을 필수로 한다.
- 날짜/위치는 고급 picker 없이 텍스트 중심으로 1차 구현한다.
- 위치는 `placeName` 텍스트만 전송하고 `latitude`, `longitude`는 전송하지 않는다.
- 수정 화면에서 날짜/위치 저장은 백엔드 Issue #55의 `UpdatePostRequest` 보강을 전제로 한다.
- 소비 게시글 삭제 시 연결 거래 무효 처리는 백엔드 Issue #55 보강 후 일반 게시글과 같은 삭제 흐름으로 처리한다.

## 구현 단계

1. 게시글 모델과 `PostService`를 추가한다.
2. `PostService` 단위 테스트로 경로, query, body, Authorization 헤더를 검증한다.
3. 첨부 모델과 응답 파싱 테스트를 추가한다.
4. `TripDetailScreen`에 피드 상태를 추가한다.
5. 피드 탭, 목록, 빈 상태, 오류 상태를 구현한다.
6. 카드별 상세 보강 조회로 첨부 미리보기를 표시한다.
7. `PostFormScreen`을 작성/수정 공용으로 추가한다.
8. 내 여행 참여자 조회를 추가하고 작성자 메뉴 노출을 연결한다.
9. 소비 카드 금액 보강 조회를 연결한다.
10. 여행 정보 바텀시트와 기존 여행 수정/삭제 흐름을 이동한다.
11. 삭제 확인 다이얼로그와 목록 갱신을 연결한다.
12. smoke/widget 테스트를 추가한다.

## 테스트 계획

- `flutter analyze`
- `flutter test`
- 단위 테스트:
  - 게시글 목록 요청이 `/api/trips/{tripId}/posts`로 나가는지
  - `postType`, `cursor`, `size` query가 포함되는지
  - 작성/수정 body가 서버 DTO와 맞는지
  - 게시글 상세 보강 조회로 `attachments`를 파싱하는지
  - 삭제 요청이 올바른 path로 나가는지
  - 내 여행 참여자 조회 path와 query가 맞는지
  - 거래 상세 보강 조회 path가 맞는지
- 위젯 테스트:
  - 여행 상세 빈 피드 상태
  - 피드 카드에서 첨부 미리보기 표시
  - FAB에서 기록 작성 진입
  - 작성자 카드에만 더보기 메뉴 표시
  - 여행 정보 바텀시트 표시
  - 탭별 빈 상태 문구 표시

## 위험

- 현재 `TripDetailScreen`이 여행 기본 정보 중심이라 피드까지 넣으면 파일이 커질 수 있다. 위젯 분리가 필요하다.
- 서버가 소비형 게시글과 거래 생성을 어떻게 연결하는지 불명확하다. 이 계획에서는 게시글 CRUD와 소비 등록을 분리한다.
- 작성자 권한 판별에 현재 사용자 participant 정보가 필요하다. 조회 실패 시 메뉴를 숨기는 정책으로 UX가 보수적으로 동작한다.
- 이번 프론트 범위에서는 첨부 표시만 구현한다. 작성/수정 첨부 입력은 백엔드 업로드 URL 발급과 첨부 수정 API가 확정된 뒤 별도 범위로 진행한다.
- 현재 백엔드 `UpdatePostRequest`에는 날짜/위치 수정 필드가 없다. #55 반영 전에는 수정 화면에서 날짜/위치 저장이 실패하거나 무시될 수 있다.
- 소비 게시글 삭제가 연결 거래 무효 처리까지 보장되려면 백엔드 #55가 먼저 반영되어야 한다.
