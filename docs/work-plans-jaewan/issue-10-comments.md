# Issue 10 구현 계획: 댓글 목록/작성/삭제

## 임무

게시글 상세 또는 피드 카드에서 댓글 바텀시트를 열고, 원댓글 목록 조회/작성/삭제를 지원한다.

## 범위

- 댓글 모델 추가
- `PostService`에 댓글 API 메서드 추가
- 댓글 바텀시트 UI
- 댓글 목록 cursor 조회
- 댓글 작성 입력창
- 댓글 삭제 확인 흐름
- 댓글 작성/삭제 후 댓글 수와 목록 갱신

## 제외 범위

- 대댓글 작성/표시
- 댓글 수정
- 알림 연동
- 실시간 갱신

## 참고

- 와이어프레임:
  - 댓글 바텀시트: `docs/togethertrip_wireframes.html` 섹션 6
- API:
  - `GET /api/trips/{tripId}/posts/{postId}/comments`
  - `POST /api/trips/{tripId}/posts/{postId}/comments`
  - `DELETE /api/trips/{tripId}/posts/{postId}/comments/{commentId}`

## 설계

### 파일 구성

- `lib/features/post/widget/comment_bottom_sheet.dart`
- `lib/features/post/service/post_service.dart`에 댓글 메서드 추가
- 테스트:
  - `test/features/post/service/post_service_test.dart`
  - 필요 시 `test/features/post/widget/comment_bottom_sheet_test.dart`

### 모델

- `PostComment`
  - `id`, `postId`, `authorParticipantId`, `authorDisplayName`, `content`, `commentDepth`, `createdAt`, `updatedAt`
- `CommentListPage`
  - `items`, `size`, `nextCursor`, `hasNext`
- `CreateCommentInput`
  - `content`

### 화면 흐름

1. 피드 카드 또는 게시글 상세의 댓글 버튼을 누르면 바텀시트를 연다.
2. 바텀시트 open 시 첫 페이지를 조회한다.
3. 댓글 입력 후 전송하면 `POST`를 호출한다.
4. 성공 시 입력창을 비우고 목록 첫 페이지를 다시 조회한다.
5. 삭제 가능한 댓글은 더보기/롱프레스/삭제 버튼 중 하나로 삭제 확인을 띄운다.
6. 삭제 성공 시 목록과 댓글 수를 갱신한다.

## 구현 단계

1. 댓글 모델과 `PostService` 메서드를 추가한다.
2. 댓글 API 단위 테스트를 추가한다.
3. 바텀시트 UI를 만든다.
4. 게시글 상세/피드 카드에서 바텀시트를 여는 콜백을 연결한다.
5. 작성/삭제 성공 후 부모 화면에 변경 여부를 전달한다.
6. 오류, 빈 상태, 추가 로딩 상태를 정리한다.

## 테스트 계획

- `flutter analyze`
- `flutter test`
- 단위 테스트:
  - 댓글 목록 path/query
  - 댓글 작성 body
  - 댓글 삭제 path
- 위젯 테스트:
  - 빈 댓글 상태
  - 댓글 입력 후 전송 버튼 활성화
  - 삭제 확인 다이얼로그

## 위험

- 삭제 권한 판별이 UI에서 불명확할 수 있다. 1차는 서버 실패 메시지를 보여주는 방식으로 처리 가능하다.
- 바텀시트 내부 cursor 추가 로딩은 스크롤 컨트롤러가 필요해 테스트가 조금 번거롭다.
- 댓글 수는 게시글 상세/목록 양쪽에 표시될 수 있어 갱신 경로를 명확히 해야 한다.
