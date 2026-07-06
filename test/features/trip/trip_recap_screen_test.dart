import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/trip/screen/trip_recap_screen.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('Recap 상세 화면은 scene imageUrl을 인증 bytes 조회 경로로 사용한다', (
    tester,
  ) async {
    final tripService = _FakeTripService();

    await tester.pumpWidget(
      MaterialApp(home: TripRecapScreen(tripId: 10, tripService: tripService)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tripService.requestedImageUrls, [
      '/api/trips/10/recap/scenes/200/image',
    ]);
  });
}

class _FakeTripService extends TripService {
  final requestedImageUrls = <String>[];

  @override
  Future<TripRecap> getRecap(int tripId) async {
    return const TripRecap(
      recapId: 100,
      tripId: 10,
      style: TripRecapStyle.photo,
      status: TripRecapStatusValue.completed,
      scenes: [
        TripRecapScene(
          sceneId: 200,
          order: 1,
          imageUrl: '/api/trips/10/recap/scenes/200/image',
          aspectRatio: '9:16',
        ),
      ],
    );
  }

  @override
  Future<List<int>> getRecapSceneImageBytes(String imageUrl) async {
    requestedImageUrls.add(imageUrl);
    return const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ];
  }
}
