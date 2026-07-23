# 정산 UI 구현 계획

- GitHub Issue: https://github.com/together-trip/togethertrip-client-flutter/issues/15
- 작업 브랜치: `feature/issue-15-settlement-ui`
- 기준 브랜치: `develop`

## 선택안

- 구조: 후보 A
- 스타일: 후보 C wireframe
- 설명: 정산 계산 방법 모달

## 1차 범위

- mock-first 정산 화면
- 여행 상세 정산 진입 연결
- 전체 현황 / 송금 / 수금 탭
- 정산 미리보기, 정산하기, 공유 CTA 상태
- 송금 완료, 수금 완료, 자동 확인됨 표시

## 후속 커밋 범위

- 실제 Settlement API 연동
- 정산 미리보기/확정/공유/송금 확인 API 연결
- 에러/로딩 상태 보강

## 제외 범위

- 백엔드 API 변경
- 미리보기 상태 공유
- 정산 확정 취소
- 실제 송금 API 연동

## 검증

- `flutter analyze`
- `flutter test`
