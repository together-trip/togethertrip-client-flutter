# Issue 10 구현 계획: 소비 등록

## 임무

여행 상세 페이지에서 소비 등록 화면으로 진입해 거래를 생성한다. 와이어프레임의 소비 등록 금액/분배, 내용 입력 흐름을 1차 구현한다.

## 범위

- 소비 등록 진입 바텀시트의 소비 선택
- 소비 등록 화면
- 금액, 통화, 결제자, 부담자 입력
- 균등 분배 보조 기능
- 제목, 카테고리, 내용 입력
- 여행 참여자 목록을 결제자/부담자 입력에 연결
- `TransactionService`와 거래 모델 추가
- 등록 성공 후 여행 상세 피드 갱신

## 제외 범위

- 소비 수정/삭제
- 결제 정보 바텀시트
- 파일 저장소 업로드, 업로드 URL 발급, 이미지 리사이징
- 지도/위치 선택 고도화
- 환율 미리보기 UI 고도화
- 공동경비 충전/사용

## 참고

- 와이어프레임:
  - 등록 선택 바텀시트: `docs/togethertrip_wireframes.html` 섹션 5
  - 소비 등록 금액/분배: `docs/togethertrip_wireframes.html` 섹션 5
  - 소비 등록 내용: `docs/togethertrip_wireframes.html` 섹션 5
- API:
  - `POST /api/trips/{tripId}/transactions`
  - `GET /api/trips/{tripId}`의 `participants`

## 설계

### 파일 구성

- `lib/features/transaction/service/transaction_service.dart`
- `lib/features/transaction/screen/expense_form_screen.dart`
- 필요 시 `lib/features/transaction/widget/participant_amount_row.dart`
- 테스트:
  - `test/features/transaction/service/transaction_service_test.dart`
  - 필요 시 `test/features/transaction/screen/expense_form_screen_test.dart`

### 모델

- `TransactionDetail`
- `TransactionSummary`
- `TransactionPayment`
- `TransactionShare`
- `TransactionFormInput`
  - `transactionType`, `amount`, `currency`, `payments`, `shares`
- `TransactionPaymentInput`
  - `participantId`, `amount`
- `TransactionShareInput`
  - `participantId`, `shareAmount`, `shareRatio`

### 화면 흐름

1. `TripDetailScreen` FAB에서 등록 선택 바텀시트를 연다.
2. 소비를 선택하면 `ExpenseFormScreen`으로 이동한다.
3. 화면은 여행의 활성 참여자 목록을 기반으로 결제자/부담자 행을 만든다.
4. 기본값:
   - 통화: 여행 `defaultCurrency`
   - 결제자: 현재 사용자와 연결된 참여자가 있으면 해당 참여자에게 전체 금액
   - 부담자: 활성 참여자 전체 균등 분배
5. 금액 변경 시 균등 분배 금액을 다시 계산한다.
6. 등록 시 `POST /transactions`를 호출한다.
7. 성공 시 화면을 닫고 여행 상세 피드를 갱신한다.

## 구현 단계

1. 거래 모델과 `TransactionService.createTransaction`을 추가한다.
2. 거래 생성 단위 테스트를 추가한다.
3. 소비 등록 화면의 금액/통화/참여자 입력 상태 모델을 만든다.
4. 균등 분배 계산과 검증 메시지를 구현한다.
5. 등록 선택 바텀시트와 소비 등록 화면 이동을 연결한다.
6. 등록 성공 후 상세 화면 갱신을 연결한다.
7. 오류/로딩/입력 검증 상태를 정리한다.

## 테스트 계획

- `flutter analyze`
- `flutter test`
- 단위 테스트:
  - 거래 생성 path와 Authorization 헤더
  - `payments`, `shares` body 변환
  - 균등 분배 계산
- 위젯 테스트:
  - 참여자 목록 기반 결제자/부담자 행 렌더링
  - 금액 입력 후 균등 분배 반영
  - 필수값 누락 시 등록 차단

## 위험

- 현재 서버 `CreateTransactionRequest`에는 제목, 카테고리, 내용, 위치가 없다. 이 값들은 거래 생성 API가 아니라 게시글 API의 필드다.
- 소비 등록 후 소비형 피드 카드를 만들려면 거래 생성 후 `POST /posts`에 `transactionId`를 연결하는 추가 호출이 필요할 수 있다.
- 환율은 서버가 거래 생성 시 처리하므로, 1차 UI의 환산 금액은 표시하지 않거나 추후 `GET /transactions/exchange-rate` 연동으로 분리하는 편이 안전하다.
