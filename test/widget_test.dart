import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/main.dart';

void main() {
  testWidgets('TogetherTripApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TogetherTripApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
