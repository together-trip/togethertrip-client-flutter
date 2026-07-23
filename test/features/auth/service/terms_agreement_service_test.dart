import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/auth/service/terms_agreement_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

void main() {
  group('TermsAgreementService', () {
    test('약관 저장 시 미동의 선택 약관도 agreed=false로 전송한다', () async {
      Map<String, dynamic>? capturedBody;
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/api/terms') {
              return http.Response(
                jsonEncode(
                  _apiResponse([
                    {
                      'code': 'SERVICE_TERMS',
                      'title': '서비스 이용약관',
                      'required': true,
                      'version': '2026-06-18',
                      'content': '서비스 약관',
                    },
                    {
                      'code': 'PRIVACY_POLICY',
                      'title': '개인정보 처리방침',
                      'required': true,
                      'version': '2026-06-18',
                      'content': '개인정보 약관',
                    },
                    {
                      'code': 'LOCATION_INFO_TERMS',
                      'title': '위치기반서비스 이용약관',
                      'required': true,
                      'version': '2026-06-18',
                      'content': '위치 약관',
                    },
                    {
                      'code': 'MARKETING_CONSENT',
                      'title': '광고성 정보 수신 동의',
                      'required': false,
                      'version': '2026-06-18',
                      'content': '마케팅 약관',
                    },
                  ]),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            expect(request.url.path, '/api/terms/agreements');
            expect(request.headers['Authorization'], 'Bearer access-token');
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(_apiResponse({'agreements': []})),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await service.saveAgreements(
        agreedTerms: const [
          TermsAgreementItem(
            code: 'SERVICE_TERMS',
            title: '서비스 이용약관',
            version: '2026-06-18',
            required: true,
            summary: '서비스 약관',
          ),
          TermsAgreementItem(
            code: 'PRIVACY_POLICY',
            title: '개인정보 처리방침',
            version: '2026-06-18',
            required: true,
            summary: '개인정보 약관',
          ),
          TermsAgreementItem(
            code: 'LOCATION_INFO_TERMS',
            title: '위치기반서비스 이용약관',
            version: '2026-06-18',
            required: true,
            summary: '위치 약관',
          ),
        ],
      );

      final agreements = capturedBody?['agreements'] as List<dynamic>;
      expect(agreements, hasLength(4));
      expect(agreements.last, containsPair('code', 'MARKETING_CONSENT'));
      expect(agreements.last, containsPair('agreed', false));
      expect(agreements.last, containsPair('version', '2026-06-18'));
    });

    test('필수 약관 목록이 비어 있으면 저장하지 않는다', () async {
      var putCalled = false;
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/api/terms') {
              return http.Response(
                jsonEncode(_apiResponse([])),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            putCalled = true;
            return http.Response(
              jsonEncode(_apiResponse({'agreements': []})),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(
        () => service.saveAgreements(agreedTerms: const []),
        throwsA(isA<StateError>()),
      );
      expect(putCalled, isFalse);
    });

    test('원격 약관 목록이 비어 있으면 mock 약관으로 대체하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms');
            return http.Response(
              jsonEncode(_apiResponse([])),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(await service.getTerms(), isEmpty);
    });

    test('원격 약관 항목의 필수 필드가 누락되면 조용히 선택 약관으로 처리하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms');
            return http.Response(
              jsonEncode(
                _apiResponse([
                  {
                    'code': 'SERVICE_TERMS',
                    'title': '서비스 이용약관',
                    'version': '2026-06-18',
                    'content': '서비스 약관',
                  },
                ]),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getTerms, throwsA(isA<FormatException>()));
    });

    test('원격 약관 항목이 객체가 아니면 조용히 무시하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms');
            return http.Response(
              jsonEncode(
                _apiResponse([
                  {
                    'code': 'SERVICE_TERMS',
                    'title': '서비스 이용약관',
                    'required': true,
                    'version': '2026-06-18',
                    'content': '서비스 약관',
                  },
                  'BROKEN_TERM',
                ]),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getTerms, throwsA(isA<FormatException>()));
    });

    test('원격 약관 코드가 중복되면 조용히 병합하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms');
            return http.Response(
              jsonEncode(
                _apiResponse([
                  {
                    'code': 'SERVICE_TERMS',
                    'title': '서비스 이용약관',
                    'required': true,
                    'version': '2026-06-18',
                    'content': '서비스 약관',
                  },
                  {
                    'code': 'SERVICE_TERMS',
                    'title': '서비스 이용약관',
                    'required': true,
                    'version': '2026-06-19',
                    'content': '서비스 약관 v2',
                  },
                ]),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getTerms, throwsA(isA<FormatException>()));
    });

    test('원격 약관 동의 상태는 agreed=true 코드만 반환한다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms/agreements/me');
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'agreements': [
                    {'code': 'SERVICE_TERMS', 'agreed': true},
                    {'code': 'MARKETING_CONSENT', 'agreed': false},
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(await service.getAgreedTermCodes(), {'SERVICE_TERMS'});
    });

    test('원격 약관 동의 목록이 배열이 아니면 조용히 미동의 처리하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms/agreements/me');
            return http.Response(
              jsonEncode(_apiResponse({'agreements': 'BROKEN'})),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getAgreedTermCodes, throwsA(isA<FormatException>()));
    });

    test('원격 약관 동의 항목의 agreed가 bool이 아니면 조용히 무시하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms/agreements/me');
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'agreements': [
                    {'code': 'SERVICE_TERMS', 'agreed': 'true'},
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getAgreedTermCodes, throwsA(isA<FormatException>()));
    });

    test('원격 약관 동의 코드가 중복되면 조용히 병합하지 않는다', () async {
      final service = TermsAgreementService(
        authService: _TokenAuthService(),
        useRemoteApi: true,
        apiClient: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/terms/agreements/me');
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'agreements': [
                    {'code': 'SERVICE_TERMS', 'agreed': true},
                    {'code': 'SERVICE_TERMS', 'agreed': true},
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      expect(service.getAgreedTermCodes, throwsA(isA<FormatException>()));
    });
  });
}

class _TokenAuthService extends AuthService {
  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}
