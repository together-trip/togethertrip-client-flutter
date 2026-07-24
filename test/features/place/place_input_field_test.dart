import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:togethertrip/features/place/model/place_models.dart';
import 'package:togethertrip/features/place/service/place_service.dart';
import 'package:togethertrip/features/place/widget/place_input_field.dart';

void main() {
  testWidgets('빈 장소 입력을 열어 지도 좌표를 선택하면 변경 값을 반환한다', (tester) async {
    PlaceSelection? changed;
    await tester.pumpWidget(
      _harness(selection: null, onChanged: (value) => changed = value),
    );

    expect(find.text('검색하거나 지도에서 선택'), findsOneWidget);
    final labelBottom = tester.getBottomLeft(find.text('장소')).dy;
    final hintTop = tester.getTopLeft(find.text('검색하거나 지도에서 선택')).dy;
    expect(labelBottom, lessThan(hintTop));
    expect(
      tester.getSize(find.byKey(const ValueKey('placeInputField'))).height,
      greaterThanOrEqualTo(52),
    );
    await tester.tap(find.byKey(const ValueKey('placeInputField')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inputFieldFakeMap')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(changed?.name, '도쿄역');
    expect(changed?.latitude, 35.681236);
  });

  testWidgets('선택된 장소의 지우기 버튼은 null 변경 값을 반환한다', (tester) async {
    PlaceSelection? changed = _selection;
    await tester.pumpWidget(
      _harness(selection: _selection, onChanged: (value) => changed = value),
    );

    expect(find.text('도쿄역'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clearPlaceButton')));
    await tester.pump();

    expect(changed, isNull);
  });

  testWidgets('비활성 장소 입력은 picker를 열거나 장소를 지우지 않는다', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _harness(
        selection: _selection,
        enabled: false,
        onChanged: (_) => changes += 1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('placeInputField')));
    await tester.tap(find.byKey(const ValueKey('clearPlaceButton')));
    await tester.pumpAndSettle();

    expect(find.text('장소 선택'), findsNothing);
    expect(changes, 0);
  });

  testWidgets('picker를 선택 없이 닫으면 변경 callback을 호출하지 않는다', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _harness(selection: null, onChanged: (_) => changes += 1),
    );

    await tester.tap(find.byKey(const ValueKey('placeInputField')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();

    expect(changes, 0);
  });
}

Widget _harness({
  required PlaceSelection? selection,
  required ValueChanged<PlaceSelection?> onChanged,
  bool enabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PlaceInputField(
        tripId: 10,
        selection: selection,
        enabled: enabled,
        onChanged: onChanged,
        placeService: _FakePlaceService(),
        mapBuilder: (_, onCoordinateSelected) => Center(
          child: FilledButton(
            key: const ValueKey('inputFieldFakeMap'),
            onPressed: () =>
                onCoordinateSelected(const LatLng(35.681236, 139.767125)),
            child: const Text('좌표 선택'),
          ),
        ),
      ),
    ),
  );
}

class _FakePlaceService extends PlaceService {
  @override
  Future<PlaceSelection> reverseGeocode(
    int tripId, {
    required double latitude,
    required double longitude,
    String languageCode = 'ko',
  }) async => _selection;
}

const _selection = PlaceSelection(
  placeId: 'place-1',
  name: '도쿄역',
  address: '일본 도쿄도',
  latitude: 35.681236,
  longitude: 139.767125,
);
