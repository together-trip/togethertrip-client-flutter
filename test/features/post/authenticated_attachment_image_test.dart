import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/post/widget/authenticated_attachment_image.dart';
import 'package:togethertrip/features/post/widget/attachment_input_section.dart';
import 'package:togethertrip/features/post/service/post_service.dart';

void main() {
  test('상대 attachment API 경로를 Bearer token과 함께 bytes로 조회한다', () async {
    Uri? requestedUri;
    String? authorization;
    final loader = AuthenticatedAttachmentImageLoader(
      authService: _FakeAuthService(),
      apiClient: ApiClient(
        client: MockClient((request) async {
          requestedUri = request.url;
          authorization = request.headers['Authorization'];
          return http.Response.bytes(_onePixelPng, 200);
        }),
      ),
    );

    final bytes = await loader.load('/api/trips/10/posts/20/attachments/30');

    expect(requestedUri!.path, '/api/trips/10/posts/20/attachments/30');
    expect(authorization, 'Bearer access-token');
    expect(bytes, _onePixelPng);
  });

  test('인증 attachment API의 401을 ApiException으로 전달한다', () async {
    final loader = AuthenticatedAttachmentImageLoader(
      authService: _FakeAuthService(),
      apiClient: ApiClient(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({'success': false, 'message': '인증이 필요합니다.'}),
            ),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    await expectLater(
      loader.load('/api/trips/10/posts/20/attachments/30'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', '인증이 필요합니다.'),
      ),
    );
  });

  testWidgets('bytes 조회 성공 시 메모리 이미지를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedAttachmentImage(
          path: '/api/trips/10/posts/20/attachments/30',
          loader: _WidgetLoader(bytes: _onePixelPng),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('bytes와 MemoryImage를 재사용하고 표시 크기에 맞춰 디코딩한다', (tester) async {
    final loader = _WidgetLoader(bytes: _onePixelPng);

    Widget buildApp() {
      return MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Center(
            child: SizedBox(
              width: 40,
              height: 30,
              child: AuthenticatedAttachmentImage(
                path: '/api/trips/10/posts/20/attachments/30',
                loader: loader,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final firstImage = tester.widget<Image>(find.byType(Image));
    final firstProvider = firstImage.image as ResizeImage;

    await tester.pumpWidget(buildApp());
    await tester.pump();
    final rebuiltImage = tester.widget<Image>(find.byType(Image));
    final rebuiltProvider = rebuiltImage.image as ResizeImage;

    expect(loader.loadCount, 1);
    expect(
      identical(firstProvider.imageProvider, rebuiltProvider.imageProvider),
      isTrue,
    );
    expect(firstProvider.width, 80);
    expect(firstProvider.height, 60);
  });

  testWidgets('bytes 조회 실패 시 안전한 오류 UI를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedAttachmentImage(
          path: '/api/trips/10/posts/20/attachments/30',
          loader: _WidgetLoader(error: Exception('broken image')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('첨부 수정 미리보기는 인증 image loader에 상대 API 경로를 전달한다', (tester) async {
    final loader = _RecordingWidgetLoader();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentInputSection(
            attachments: const [],
            existingAttachments: const [
              PostAttachment(
                id: 30,
                attachmentType: 'IMAGE',
                fileUrl: '/api/trips/10/posts/20/attachments/30',
                thumbnailUrl: null,
                fileSize: null,
                mimeType: 'image/png',
                sortOrder: 0,
              ),
            ],
            enabled: true,
            attachmentImageLoader: loader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loader.paths, ['/api/trips/10/posts/20/attachments/30']);
    expect(find.byType(Image), findsOneWidget);
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}

class _WidgetLoader extends AuthenticatedAttachmentImageLoader {
  _WidgetLoader({this.bytes, this.error});
  final List<int>? bytes;
  final Object? error;
  int loadCount = 0;

  @override
  Future<Uint8List> load(String path) async {
    loadCount += 1;
    if (error != null) throw error!;
    return bytes is Uint8List
        ? bytes! as Uint8List
        : Uint8List.fromList(bytes!);
  }
}

class _RecordingWidgetLoader extends AuthenticatedAttachmentImageLoader {
  final paths = <String>[];

  @override
  Future<Uint8List> load(String path) async {
    paths.add(path);
    return Uint8List.fromList(_onePixelPng);
  }
}

final List<int> _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
