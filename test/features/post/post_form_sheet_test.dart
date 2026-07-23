import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/post/screen/post_form_sheet.dart';
import 'package:togethertrip/features/post/service/post_service.dart';

void main() {
  testWidgets('기존 장소 좌표를 수정 폼에서 유지해 전송한다', (tester) async {
    PostFormInput? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostFormSheet(
            tripId: 10,
            postType: 'RECORD',
            initialPost: _post,
            onSubmit: (input) async => submitted = input,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('savePostButton'));
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(submitted?.placeName, '도쿄역');
    expect(submitted?.latitude, 35.681236);
    expect(submitted?.longitude, 139.767125);
  });
}

const _post = PostDetail(
  id: 2,
  tripId: 10,
  transactionId: null,
  authorParticipantId: 100,
  authorDisplayName: '재완',
  postType: 'RECORD',
  title: '도쿄 도착',
  category: '관광',
  content: '내용',
  occurredAt: '2026-07-02T03:00:00Z',
  placeName: '도쿄역',
  latitude: 35.681236,
  longitude: 139.767125,
  commentCount: 0,
  attachments: [],
  createdAt: '2026-07-02T03:00:00Z',
  updatedAt: '2026-07-02T03:00:00Z',
);
