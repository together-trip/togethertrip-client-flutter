import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/settlement/model/settlement_models.dart';
import 'package:togethertrip/features/settlement/service/settlement_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

http.Response _jsonResponse(dynamic data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('SettlementService', () {
    test('정산 요약을 조회하고 balance-summary DTO를 화면 모델로 변환한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final service = SettlementService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            return _jsonResponse(_apiResponse(_balanceSummaryData()), 200);
          }),
        ),
        authService: _FakeAuthService(),
      );

      final overview = await service.getOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        isOwner: true,
        currentParticipantId: 100,
      );

      expect(capturedUrl!.path, '/api/trips/10/balance-summary');
      expect(capturedAuth, 'Bearer access-token');
      expect(overview.stage, SettlementStage.notStarted);
      expect(overview.currentBalance.receiveAmount, 46860);
      expect(
        overview.balances.singleWhere((item) => item.isWithdrawn).displayName,
        '탈퇴한 사용자',
      );
    });

    test('정산 진행중 여행으로 다시 진입하면 확정 정산과 송금 목록을 유지한다', () async {
      final requested = <String>[];
      Uri? transferUrl;
      final service = SettlementService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            requested.add('${request.method} ${request.url.path}');
            if (request.url.path.endsWith('/balance-summary')) {
              return _jsonResponse(_apiResponse(_balanceSummaryData()), 200);
            }
            if (request.url.path.endsWith('/settlement-transfers')) {
              transferUrl = request.url;
              return _jsonResponse(
                _apiResponse([_confirmedTransferData()]),
                200,
              );
            }
            return _jsonResponse(_apiResponse(null), 404);
          }),
        ),
        authService: _FakeAuthService(),
      );

      final overview = await service.getOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        isOwner: true,
        currentParticipantId: 100,
        tripSettlementStatus: 'IN_PROGRESS',
      );

      expect(overview.stage, SettlementStage.confirmed);
      expect(overview.receivedTransfers.single.id, 1);
      expect(requested, contains('GET /api/trips/10/balance-summary'));
      expect(requested, contains('GET /api/trips/10/settlement-transfers'));
      expect(transferUrl!.queryParameters.containsKey('participantId'), isFalse);
    });

    test('다른 참여자의 미완료 송금이 남아 있으면 전체 정산 완료로 보지 않는다', () {
      final overview = SettlementOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        baseCurrency: 'KRW',
        stage: SettlementStage.confirmed,
        currentParticipantId: 23,
        isOwner: false,
        settlementId: 901,
        shareToken: null,
        balances: const [],
        transfers: [
          SettlementTransferItem.fromJson({
            'id': 14,
            'senderParticipantId': 25,
            'senderDisplayName': '동행자 1',
            'receiverParticipantId': 23,
            'receiverDisplayName': '요술다람쥐',
            'amount': 635317.9,
            'currency': 'KRW',
            'status': 'COMPLETED',
            'senderConfirmedAt': '2026-06-25T15:34:40.933712Z',
            'receiverConfirmedAt': '2026-06-25T15:34:49.011940Z',
            'completedAt': '2026-06-25T15:34:49.011940Z',
            'autoConfirmed': true,
          }),
          SettlementTransferItem.fromJson({
            'id': 15,
            'senderParticipantId': 25,
            'senderDisplayName': '동행자 1',
            'receiverParticipantId': 24,
            'receiverDisplayName': '로컬 verified hana',
            'amount': 17719677.7,
            'currency': 'KRW',
            'status': 'SENDER_CONFIRMED',
            'senderConfirmedAt': '2026-06-25T15:34:40.939760Z',
            'receiverConfirmedAt': null,
            'completedAt': null,
            'autoConfirmed': true,
          }),
        ],
      );

      expect(overview.receivedTransfers.map((transfer) => transfer.id), [14]);
      expect(overview.allTransfersCompleted, isFalse);
    });

    test('미리보기, 확정, 공유, 수금 확인 API를 호출하고 모델을 갱신한다', () async {
      final requested = <String>[];
      final service = SettlementService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            requested.add('${request.method} ${request.url.path}');
            final path = request.url.path;
            if (path.endsWith('/balance-summary')) {
              return _jsonResponse(_apiResponse(_balanceSummaryData()), 200);
            }
            if (path.endsWith('/settlement-preview')) {
              return _jsonResponse(_apiResponse(_previewData()), 200);
            }
            if (path.endsWith('/settlements')) {
              return _jsonResponse(_apiResponse(_settlementData()), 200);
            }
            if (path.endsWith('/share-tokens')) {
              return _jsonResponse(
                _apiResponse({
                  'settlementId': 901,
                  'shareToken': 'share-token',
                }),
                200,
              );
            }
            if (path.endsWith('/receiver-confirmation')) {
              return _jsonResponse(_apiResponse(_completedTransferData()), 200);
            }
            return _jsonResponse(_apiResponse(null), 404);
          }),
        ),
        authService: _FakeAuthService(),
      );

      await service.getOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        isOwner: true,
        currentParticipantId: 100,
      );

      final preview = await service.previewSettlement();
      expect(preview.stage, SettlementStage.previewed);
      expect(preview.receivedTransfers.single.id, 0);

      final confirmed = await service.confirmSettlement();
      expect(confirmed.stage, SettlementStage.confirmed);
      expect(confirmed.settlementId, 901);
      expect(confirmed.receivedTransfers.single.id, 1);

      final shared = await service.createShareToken();
      expect(shared.shareToken, 'share-token');

      final transferConfirmed = await service.confirmTransferAsReceiver(1);
      expect(transferConfirmed.receivedTransfers.single.isCompleted, isTrue);

      expect(requested, contains('GET /api/trips/10/balance-summary'));
      expect(requested, contains('POST /api/trips/10/settlement-preview'));
      expect(requested, contains('POST /api/trips/10/settlements'));
      expect(
        requested,
        contains('POST /api/trips/10/settlements/901/share-tokens'),
      );
      expect(
        requested,
        contains(
          'PATCH /api/trips/10/settlement-transfers/1/receiver-confirmation',
        ),
      );
    });

    test('송금자와 수금자가 모두 확인한 응답은 status 문자열과 무관하게 완료로 본다', () {
      final transfer = SettlementTransferItem.fromJson({
        'id': 1,
        'senderParticipantId': 101,
        'senderDisplayName': '민지',
        'receiverParticipantId': 100,
        'receiverDisplayName': '나',
        'amount': 46860,
        'currency': 'KRW',
        'status': 'SENDER_CONFIRMED',
        'senderConfirmedAt': '2026-06-16T00:01:00Z',
        'receiverConfirmedAt': '2026-06-16T00:02:00Z',
        'completedAt': null,
      });

      final overview = SettlementOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        baseCurrency: 'KRW',
        stage: SettlementStage.confirmed,
        currentParticipantId: 100,
        isOwner: false,
        settlementId: 901,
        shareToken: null,
        balances: const [],
        transfers: [transfer],
      );

      expect(transfer.status, SettlementTransferStatus.completed);
      expect(transfer.isCompleted, isTrue);
      expect(overview.allTransfersCompleted, isTrue);
    });

    test('탈퇴한 사용자는 기본 확인된 것으로 보고 반대쪽 확인만 있으면 완료로 본다', () {
      final transfer = SettlementTransferItem.fromJson({
        'id': 2,
        'senderParticipantId': 102,
        'senderDisplayName': '탈퇴한 사용자',
        'receiverParticipantId': 100,
        'receiverDisplayName': '나',
        'amount': 12000,
        'currency': 'KRW',
        'status': 'RECEIVER_CONFIRMED',
        'senderConfirmedAt': null,
        'receiverConfirmedAt': '2026-06-16T00:02:00Z',
        'completedAt': null,
      });

      final overview = SettlementOverview(
        tripId: 10,
        tripTitle: '오사카 여행',
        baseCurrency: 'KRW',
        stage: SettlementStage.confirmed,
        currentParticipantId: 100,
        isOwner: false,
        settlementId: 901,
        shareToken: null,
        balances: const [],
        transfers: [transfer],
      );

      expect(transfer.senderConfirmed, isTrue);
      expect(transfer.receiverConfirmed, isTrue);
      expect(transfer.isCompleted, isTrue);
      expect(overview.allTransfersCompleted, isTrue);
    });
  });
}

Map<String, dynamic> _balanceSummaryData() => {
  'tripId': 10,
  'tripExpenseVersion': 3,
  'baseCurrency': 'KRW',
  'balances': _balancesData(),
};

Map<String, dynamic> _previewData() => {
  'tripId': 10,
  'tripExpenseVersion': 3,
  'baseCurrency': 'KRW',
  'totalExpenseAmount': 210000,
  'totalShareAmount': 210000,
  'balances': _balancesData(),
  'transfers': [_previewTransferData()],
};

Map<String, dynamic> _settlementData() => {
  'id': 901,
  'tripId': 10,
  'status': 'CONFIRMED',
  'tripExpenseVersion': 3,
  'calculationVersion': 'settlement-v1',
  'baseCurrency': 'KRW',
  'totalExpenseAmount': 210000,
  'totalShareAmount': 210000,
  'confirmedAt': '2026-06-16T00:00:00Z',
  'confirmedByUserId': 1,
  'balances': _balancesData(),
  'transfers': [_confirmedTransferData()],
};

List<Map<String, dynamic>> _balancesData() => [
  {
    'participantId': 100,
    'userId': 1,
    'displayName': '나',
    'profileImageUrl': null,
    'participantStatus': 'ACTIVE',
    'paidAmount': 125400,
    'shareAmount': 78540,
    'netAmount': 46860,
  },
  {
    'participantId': 101,
    'userId': 2,
    'displayName': '민지',
    'profileImageUrl': null,
    'participantStatus': 'ACTIVE',
    'paidAmount': 45200,
    'shareAmount': 92060,
    'netAmount': -46860,
  },
  {
    'participantId': 102,
    'userId': null,
    'displayName': '탈퇴한 사용자',
    'profileImageUrl': null,
    'participantStatus': 'LEFT',
    'paidAmount': 0,
    'shareAmount': 0,
    'netAmount': 0,
  },
];

Map<String, dynamic> _previewTransferData() => {
  'id': null,
  'senderParticipantId': 101,
  'senderDisplayName': '민지',
  'receiverParticipantId': 100,
  'receiverDisplayName': '나',
  'amount': 46860,
  'currency': 'KRW',
  'status': 'PENDING',
  'senderConfirmedAt': null,
  'receiverConfirmedAt': null,
  'completedAt': null,
};

Map<String, dynamic> _confirmedTransferData() => {
  ..._previewTransferData(),
  'id': 1,
};

Map<String, dynamic> _completedTransferData() => {
  ..._confirmedTransferData(),
  'status': 'COMPLETED',
  'senderConfirmedAt': '2026-06-16T00:01:00Z',
  'receiverConfirmedAt': '2026-06-16T00:02:00Z',
  'completedAt': '2026-06-16T00:02:00Z',
};

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';
}
