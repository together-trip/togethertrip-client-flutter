# Work Plan: 개인정보 수정 / 회원 탈퇴

작성일: 2026-06-04
브랜치: `feature/user-profile`

## 작업

마이페이지에서 개인정보 수정과 회원 탈퇴를 구현한다. 개인정보 수정 화면은 회원가입 시 사용하는
프로필 입력 화면(`SignUpProfileScreen`)을 재사용하되 기존 내용을 프리필한다.

## 배경

마이페이지(`MyPlaceholderScreen`)의 "개인정보 수정"·"회원 탈퇴" 메뉴가 빈 동작(`onTap: () {}`)으로
연결돼 있었다. main API에 관련 엔드포인트가 이미 존재하므로 앱에서 연동한다.

## 연동 API (gateway 경유, 기존 `/api/...` 프리픽스)

- `GET /api/users/me` → `UserResponse` (수정 화면 프리필용 내 정보 조회)
- `PATCH /api/users/me` (`nickname`/`gender`/`birthDate`/`profileImageUrl`, 모두 선택) → 내 정보 수정
- `DELETE /api/users/me` → 회원 탈퇴 (soft delete + `status=WITHDRAWN`)
- `GET /api/users/nicknames/availability?nickname=` → 닉네임 중복 확인 (기존)

## 범위

- `ApiClient.delete()` 추가 (빈 body 응답 처리 포함)
- `AuthService.getMe()` / `AuthService.deleteAccount()` + `UserProfile` 모델 추가
- `SignUpProfileScreen` 수정 모드(`initialProfile`) 지원: 제목 "개인정보 수정", 기존 닉네임/성별/생년월일 프리필,
  완료 시 `pop(true)` 로 호출 화면 복귀
- `MyPlaceholderScreen`: 내 정보 조회로 닉네임 표시, "개인정보 수정" 진입, "회원 탈퇴" 확인 다이얼로그 → 탈퇴 → 온보딩 복귀

## 제외 범위

- 프로필 이미지 업로드/변경 (1차 MVP 외, `profileImageUrl`은 기존 값 유지만)
- 전화번호 변경 (수정 API 대상 아님)
- 알림 설정·약관 화면 (메뉴만 존재, 별도 작업)

## 설계 결정

- 수정 화면을 별도로 만들지 않고 `SignUpProfileScreen`을 재사용한다. `initialProfile != null` 이면 수정 모드.
- 닉네임 중복확인 API(`/api/users/nicknames/availability`)는 **본인 닉네임도 "사용중"으로 판단**(self 제외 안 함)한다.
  따라서 수정 모드에서 기존 닉네임은 중복확인 절차 없이 "확인됨"으로 간주한다. 닉네임을 실제로 바꾼 경우에만 재확인.
  (`PATCH`는 self를 제외하므로 닉네임 미변경 시에도 정상 통과)
- 사용자/프로필 호출은 기존 코드 관례에 맞춰 `AuthService`에 둔다(이미 `updateMyProfile`,
  `checkNicknameAvailability` 가 여기 존재). 탈퇴 시 토큰·카카오 세션을 정리한다.

## 변경 파일

- `lib/core/network/api_client.dart` — `delete()` 추가
- `lib/features/auth/service/auth_service.dart` — `getMe()`, `deleteAccount()`, `UserProfile`
- `lib/features/auth/screen/sign_up_profile_screen.dart` — 수정 모드 지원
- `lib/features/my/screen/my_placeholder_screen.dart` — 마이페이지 배선

## 테스트 계획

```bash
flutter analyze
flutter test
```

수동 확인:
- 마이페이지 진입 시 내 닉네임 표시
- "개인정보 수정" → 기존 닉네임/성별/생년월일 프리필 확인 → 값 변경 후 저장 → 마이페이지에 반영
- 닉네임 미변경 저장 시 중복확인 없이 저장됨
- "회원 탈퇴" → 확인 다이얼로그 → 탈퇴 후 온보딩으로 이동, 재로그인 시 재가입 흐름

검증 결과:
- `flutter analyze`: 통과
- `flutter test`: 통과

## 위험과 확인 사항

- 닉네임을 변경했다가 정확히 원래 값으로 되돌리면 "확인됨" 상태가 유지된다(의도된 동작).
  단, 원래 값과 다른 값으로 바꾼 뒤에는 중복확인을 다시 거쳐야 한다.
- 탈퇴 API 실패 시 토큰을 지우지 않으므로 재시도 가능. 성공 시에만 세션 정리 후 온보딩 이동.
- 보안: 개인정보(닉네임/성별/생년월일)는 화면 표시·전송만 하고 로컬 영속 저장하지 않는다. 토큰은 기존 `TokenStorage`(secure storage) 사용.

---

# GitHub 이슈 문서 (work-item 템플릿)

> 제목: `개인정보 수정 및 회원 탈퇴 구현`

## 배경

마이페이지의 "개인정보 수정", "회원 탈퇴" 메뉴가 동작하지 않는 상태다.
main API(`GET/PATCH/DELETE /api/users/me`)가 이미 존재하므로 앱에서 연동한다.
개인정보 수정 화면은 회원가입 프로필 입력 화면을 재사용하고 기존 값을 프리필한다.

## 구현 범위

- [ ] `ApiClient.delete()` 추가
- [ ] `AuthService.getMe()` / `deleteAccount()` + `UserProfile` 모델
- [ ] `SignUpProfileScreen` 수정 모드(`initialProfile`) — 제목/프리필/완료 동작 분기
- [ ] `MyPlaceholderScreen` 배선 — 닉네임 표시, 개인정보 수정 진입, 회원 탈퇴 확인 후 처리

## 제외 범위

- 프로필 이미지 업로드/변경, 전화번호 변경, 알림 설정/약관 화면

## 작업 계획

1. API 클라이언트/서비스 계층에 조회·수정·탈퇴 연동 추가
2. 회원가입 프로필 화면을 수정 모드로 재사용 (프리필)
3. 마이페이지에서 진입/탈퇴 흐름 연결
4. `flutter analyze` / `flutter test` 검증

## 검증 방법

- [ ] `flutter analyze` 무경고
- [ ] `flutter test` 통과
- [ ] 수동: 프리필/저장/반영, 닉네임 미변경 저장, 탈퇴 후 온보딩 이동

## 완료 기준

- [ ] 구현 범위 항목 반영 및 검증 통과
- [ ] `develop` 대상 PR 머지

## 참고 자료

- 작업 계획: `docs/work-plans/user-profile-edit-withdraw.md`
- 연동 API: main `UserController` (`/api/users/me`)

---

# 커밋 메시지

브랜치에 메인 셸 스캐폴딩까지 함께 있다면 논리 단위로 2개 커밋 권장:

```
feat: 메인 셸 하단 탭 및 마이페이지 진입 구조 추가
feat: 개인정보 수정 및 회원 탈퇴 기능 구현
```

이번 작업만 한 커밋으로 한다면:

```
feat: 개인정보 수정 및 회원 탈퇴 기능 구현

- ApiClient DELETE 메서드 추가
- AuthService 내 정보 조회/회원 탈퇴 및 UserProfile 모델 추가
- SignUpProfileScreen 수정 모드(기존 내용 프리필) 지원
- 마이페이지에서 개인정보 수정 진입 및 회원 탈퇴 흐름 연결
```

(prefix 원문 `feat:` + 설명 한국어 — AGENTS Git 규칙 준수)

---

# PR

- base: `develop` ← head: `feature/user-profile`
- 제목: `feat: 개인정보 수정 및 회원 탈퇴 기능 구현`
- 본문:

```
## 개요
마이페이지에서 개인정보 수정과 회원 탈퇴를 구현한다.
개인정보 수정 화면은 회원가입 프로필 입력 화면을 재사용하고 기존 값을 프리필한다.

Closes #<이슈번호>

## 변경 사항
- ApiClient: DELETE 메서드 추가
- AuthService: GET /api/users/me 조회, DELETE /api/users/me 탈퇴, UserProfile 모델
- SignUpProfileScreen: initialProfile 기반 수정 모드(제목/프리필/완료 후 복귀)
- MyPlaceholderScreen: 닉네임 표시, 개인정보 수정 진입, 회원 탈퇴 확인 다이얼로그 → 탈퇴 → 온보딩 복귀

## 연동 API
- GET /api/users/me
- PATCH /api/users/me
- DELETE /api/users/me
- GET /api/users/nicknames/availability (기존)

## 검증
- [ ] flutter analyze
- [ ] flutter test
- [ ] 수동: 프리필/저장/반영, 닉네임 미변경 저장, 탈퇴 후 온보딩 이동

## 참고
- 닉네임 중복확인 API는 본인 닉네임도 사용중으로 판단하므로, 수정 모드에서 기존 닉네임은 확인 절차 없이 통과 처리.
```
