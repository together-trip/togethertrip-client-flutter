# Issue #42 장소 선택 UI 검증

## 결과

- 기록과 소비 작성/수정 화면이 공통 장소 picker를 사용한다.
- 장소 자동완성, 검색 결과 선택, 지도 좌표 선택, 현재 위치, 직접 입력을 지원한다.
- 직접 입력으로 전환하거나 장소를 지우면 이전 좌표를 전송하지 않는다.
- 기존 텍스트-only 데이터와 기존 좌표 데이터 편집을 모두 지원한다.
- 위치 권한은 현재 위치 버튼을 누를 때만 요청하며 background 위치 권한은 추가하지 않았다.

## 실행 명령

```bash
flutter analyze
flutter test --coverage
flutter build apk --debug
flutter build ios --flavor local --debug --no-codesign
```

모두 성공했다.

- 전체 테스트: 166개 통과
- Android 산출물: `build/app/outputs/flutter-apk/app-debug.apk`
- iOS 산출물: `build/ios/iphoneos/RunnerLocal.app`

## 커버리지

- 앱 전체 LINE: 5,362 / 7,110 = 75.41%
- 신규 `lib/features/place` LINE: 284 / 284 = 100%

Flutter `lcov.info`는 branch counter를 제공하지 않아 라인 커버리지만 측정했다.

## 환경 설정

- Android: `--dart-define-from-file=config/local.json`의 `GOOGLE_MAPS_API_KEY`
- iOS: `ios/Flutter/LocalConfig.xcconfig`의 `GOOGLE_MAPS_API_KEY`
- 두 플랫폼은 서로 다른 제한 키를 사용하고 Android package/iOS bundle 및 Maps SDK API 제한을 적용한다.

## 실기기·플랫폼 검증

- iOS 실기기에서 지도 타일, 장소 자동완성, 지도 탭 핀, 직접 입력과 좌표 결합을 확인했다.
- Google Maps 플랫폼 fake로 초기 카메라, 초기 marker, 지도 선택 및 현재 위치 camera animation을 자동 검증했다.
- Geolocator 플랫폼 fake로 서비스 비활성, 권한 거부, 영구 거부, 요청 후 승인, 기존 승인 상태를 자동 검증했다.
