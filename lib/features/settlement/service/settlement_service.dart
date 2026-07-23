import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';
import '../model/settlement_models.dart';

enum SettlementMockCase {
  ownerNotStarted('방장 · 시작 전'),
  ownerPreviewed('방장 · 미리보기'),
  ownerConfirmedMixed('방장 · 확인 중'),
  memberNeedsToSend('내가 송금'),
  memberNeedsToReceive('내가 수금'),
  allCompleted('모두 완료'),
  noTransfers('정산 없음');

  final String label;

  const SettlementMockCase(this.label);
}

class SettlementService {
  final ApiClient _apiClient;
  final AuthService _authService;

  SettlementOverview? _overview;

  SettlementService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<SettlementOverview> getOverview({
    required int tripId,
    required String tripTitle,
    required bool isOwner,
    required int currentParticipantId,
    String tripSettlementStatus = 'NOT_STARTED',
    SettlementMockCase mockCase = SettlementMockCase.ownerNotStarted,
    bool reset = false,
  }) async {
    if (_overview != null && !reset) return _overview!;

    final accessToken = await _requireAccessToken();
    final sourceStatus = _sourceStatusFromTripStatus(tripSettlementStatus);
    final balanceData = await _apiClient.get(
      '/api/trips/$tripId/balance-summary',
      accessToken: accessToken,
    );
    if (balanceData == null) {
      throw const ApiException(statusCode: 500, message: '정산 요약 응답이 비어 있습니다.');
    }

    final transfers = sourceStatus == SettlementSourceStatus.settled
        ? await _getTransfers(
            accessToken: accessToken,
            tripId: tripId,
          )
        : <SettlementTransferItem>[];

    _overview = SettlementOverview.fromBalanceSummaryJson(
      json: balanceData,
      tripTitle: tripTitle,
      currentParticipantId: currentParticipantId,
      isOwner: isOwner,
      sourceStatus: sourceStatus,
      transfers: transfers,
    );
    return _overview!;
  }

  Future<SettlementOverview> previewSettlement() async {
    final current = _requireOverview();
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.post(
      '/api/trips/${current.tripId}/settlement-preview',
      {},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '정산 미리보기 응답이 비어 있습니다.',
      );
    }

    _overview = SettlementOverview.fromPreviewJson(
      json: data,
      tripTitle: current.tripTitle,
      currentParticipantId: current.currentParticipantId,
      isOwner: current.isOwner,
    );
    return _overview!;
  }

  Future<SettlementOverview> confirmSettlement() async {
    final current = _requireOverview();
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.post(
      '/api/trips/${current.tripId}/settlements',
      {},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '정산 확정 응답이 비어 있습니다.');
    }

    _overview = SettlementOverview.fromSettlementJson(
      json: data,
      tripTitle: current.tripTitle,
      currentParticipantId: current.currentParticipantId,
      isOwner: current.isOwner,
      shareToken: current.shareToken,
    );
    return _overview!;
  }

  Future<SettlementOverview> createShareToken() async {
    final current = _requireOverview();
    final settlementId = current.settlementId;
    if (settlementId == null) {
      throw const ApiException(statusCode: 400, message: '공유할 확정 정산 ID가 없습니다.');
    }

    final accessToken = await _requireAccessToken();
    final data = await _apiClient.post(
      '/api/trips/${current.tripId}/settlements/$settlementId/share-tokens',
      {},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '정산 공유 응답이 비어 있습니다.');
    }

    _overview = current.copyWith(shareToken: data['shareToken'] as String?);
    return _overview!;
  }

  Future<SettlementOverview> confirmTransferAsSender(int transferId) async {
    final current = _requireOverview();
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.patch(
      '/api/trips/${current.tripId}/settlement-transfers/$transferId/sender-confirmation',
      {},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '송금 확인 응답이 비어 있습니다.');
    }

    _overview = _replaceTransfer(
      current,
      SettlementTransferItem.fromJson(data),
    );
    return _overview!;
  }

  Future<SettlementOverview> confirmTransferAsReceiver(int transferId) async {
    final current = _requireOverview();
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.patch(
      '/api/trips/${current.tripId}/settlement-transfers/$transferId/receiver-confirmation',
      {},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '수금 확인 응답이 비어 있습니다.');
    }

    _overview = _replaceTransfer(
      current,
      SettlementTransferItem.fromJson(data),
    );
    return _overview!;
  }

  Future<List<SettlementTransferItem>> _getTransfers({
    required String accessToken,
    required int tripId,
  }) async {
    final data = await _apiClient.getList(
      '/api/trips/$tripId/settlement-transfers',
      accessToken: accessToken,
    );

    return data
        .map(
          (item) =>
              SettlementTransferItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  SettlementOverview _replaceTransfer(
    SettlementOverview current,
    SettlementTransferItem updatedTransfer,
  ) {
    return current.copyWith(
      transfers: current.transfers.map((transfer) {
        if (transfer.id != updatedTransfer.id) return transfer;
        return updatedTransfer;
      }).toList(),
    );
  }

  SettlementOverview _requireOverview() {
    final overview = _overview;
    if (overview == null) {
      throw StateError('정산 화면 데이터가 아직 준비되지 않았습니다.');
    }
    return overview;
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }

  SettlementSourceStatus _sourceStatusFromTripStatus(String status) {
    return switch (status) {
      'IN_PROGRESS' || 'SETTLED' || 'COMPLETED' =>
        SettlementSourceStatus.settled,
      _ => SettlementSourceStatus.notStarted,
    };
  }
}

class SettlementMockService extends SettlementService {
  SettlementOverview? _mockOverview;

  @override
  Future<SettlementOverview> getOverview({
    required int tripId,
    required String tripTitle,
    required bool isOwner,
    required int currentParticipantId,
    String tripSettlementStatus = 'NOT_STARTED',
    SettlementMockCase mockCase = SettlementMockCase.ownerNotStarted,
    bool reset = false,
  }) async {
    if (_mockOverview == null || reset) {
      _mockOverview = _createMockOverview(
        tripId: tripId,
        tripTitle: tripTitle,
        isOwner: isOwner,
        currentParticipantId: currentParticipantId,
        mockCase: mockCase,
      );
    }
    return _mockOverview!;
  }

  @override
  Future<SettlementOverview> previewSettlement() async {
    final current = _requireMockOverview();
    _mockOverview = current.copyWith(stage: SettlementStage.previewed);
    return _mockOverview!;
  }

  @override
  Future<SettlementOverview> confirmSettlement() async {
    final current = _requireMockOverview();
    _mockOverview = current.copyWith(
      stage: SettlementStage.confirmed,
      settlementId: 901,
    );
    return _mockOverview!;
  }

  @override
  Future<SettlementOverview> createShareToken() async {
    final current = _requireMockOverview();
    _mockOverview = current.copyWith(shareToken: 'mock-share-token');
    return _mockOverview!;
  }

  @override
  Future<SettlementOverview> confirmTransferAsSender(int transferId) async {
    final current = _requireMockOverview();
    _mockOverview = current.copyWith(
      transfers: current.transfers.map((transfer) {
        if (transfer.id != transferId) return transfer;
        return transfer.confirmSender();
      }).toList(),
    );
    return _mockOverview!;
  }

  @override
  Future<SettlementOverview> confirmTransferAsReceiver(int transferId) async {
    final current = _requireMockOverview();
    _mockOverview = current.copyWith(
      transfers: current.transfers.map((transfer) {
        if (transfer.id != transferId) return transfer;
        return transfer.confirmReceiver();
      }).toList(),
    );
    return _mockOverview!;
  }

  SettlementOverview _requireMockOverview() {
    final overview = _mockOverview;
    if (overview == null) {
      throw StateError('정산 화면 데이터가 아직 준비되지 않았습니다.');
    }
    return overview;
  }

  SettlementOverview _createMockOverview({
    required int tripId,
    required String tripTitle,
    required bool isOwner,
    required int currentParticipantId,
    required SettlementMockCase mockCase,
  }) {
    final effectiveIsOwner = switch (mockCase) {
      SettlementMockCase.ownerNotStarted ||
      SettlementMockCase.ownerPreviewed ||
      SettlementMockCase.ownerConfirmedMixed => true,
      SettlementMockCase.memberNeedsToSend ||
      SettlementMockCase.memberNeedsToReceive ||
      SettlementMockCase.allCompleted ||
      SettlementMockCase.noTransfers => false,
    };
    final stage = switch (mockCase) {
      SettlementMockCase.ownerNotStarted => SettlementStage.notStarted,
      SettlementMockCase.ownerPreviewed => SettlementStage.previewed,
      SettlementMockCase.ownerConfirmedMixed ||
      SettlementMockCase.memberNeedsToSend ||
      SettlementMockCase.memberNeedsToReceive ||
      SettlementMockCase.allCompleted ||
      SettlementMockCase.noTransfers => SettlementStage.confirmed,
    };

    return SettlementOverview(
      tripId: tripId,
      tripTitle: tripTitle,
      baseCurrency: 'KRW',
      stage: stage,
      currentParticipantId: currentParticipantId,
      isOwner: effectiveIsOwner,
      settlementId: stage == SettlementStage.confirmed ? 901 : null,
      shareToken: mockCase == SettlementMockCase.allCompleted
          ? 'mock-share-token'
          : null,
      balances: _createBalances(
        currentParticipantId: currentParticipantId,
        isOwner: effectiveIsOwner,
        mockCase: mockCase,
      ),
      transfers: _createTransfers(
        currentParticipantId: currentParticipantId,
        mockCase: mockCase,
      ),
    );
  }

  List<SettlementBalance> _createBalances({
    required int currentParticipantId,
    required bool isOwner,
    required SettlementMockCase mockCase,
  }) {
    switch (mockCase) {
      case SettlementMockCase.memberNeedsToSend:
        return [
          SettlementBalance(
            participantId: currentParticipantId,
            displayName: '나',
            isMe: true,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 70000,
            shareAmount: 102000,
            netAmount: -32000,
          ),
          const SettlementBalance(
            participantId: 22,
            displayName: '민지',
            isMe: false,
            isOwner: true,
            isWithdrawn: false,
            paidAmount: 128000,
            shareAmount: 96000,
            netAmount: 32000,
          ),
        ];
      case SettlementMockCase.ownerConfirmedMixed:
        return [
          SettlementBalance(
            participantId: currentParticipantId,
            displayName: '나',
            isMe: true,
            isOwner: true,
            isWithdrawn: false,
            paidAmount: 70000,
            shareAmount: 82000,
            netAmount: -12000,
          ),
          const SettlementBalance(
            participantId: 22,
            displayName: '민지',
            isMe: false,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 100000,
            shareAmount: 54000,
            netAmount: 46000,
          ),
          const SettlementBalance(
            participantId: 33,
            displayName: '현우',
            isMe: false,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 20000,
            shareAmount: 54000,
            netAmount: -34000,
          ),
        ];
      case SettlementMockCase.allCompleted:
        return [
          SettlementBalance(
            participantId: currentParticipantId,
            displayName: '나',
            isMe: true,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 95000,
            shareAmount: 81000,
            netAmount: 14000,
          ),
          const SettlementBalance(
            participantId: 22,
            displayName: '민지',
            isMe: false,
            isOwner: true,
            isWithdrawn: false,
            paidAmount: 67000,
            shareAmount: 81000,
            netAmount: -14000,
          ),
        ];
      case SettlementMockCase.noTransfers:
        return [
          SettlementBalance(
            participantId: currentParticipantId,
            displayName: '나',
            isMe: true,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 60000,
            shareAmount: 60000,
            netAmount: 0,
          ),
          const SettlementBalance(
            participantId: 22,
            displayName: '민지',
            isMe: false,
            isOwner: true,
            isWithdrawn: false,
            paidAmount: 60000,
            shareAmount: 60000,
            netAmount: 0,
          ),
        ];
      case SettlementMockCase.ownerNotStarted:
      case SettlementMockCase.ownerPreviewed:
      case SettlementMockCase.memberNeedsToReceive:
        return [
          SettlementBalance(
            participantId: currentParticipantId,
            displayName: '나',
            isMe: true,
            isOwner: isOwner,
            isWithdrawn: false,
            paidAmount: 125400,
            shareAmount: 78540,
            netAmount: 46860,
          ),
          const SettlementBalance(
            participantId: 22,
            displayName: '민지',
            isMe: false,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 45200,
            shareAmount: 92060,
            netAmount: -46860,
          ),
          const SettlementBalance(
            participantId: 33,
            displayName: '현우',
            isMe: false,
            isOwner: false,
            isWithdrawn: false,
            paidAmount: 66000,
            shareAmount: 54000,
            netAmount: 12000,
          ),
          const SettlementBalance(
            participantId: 44,
            displayName: '탈퇴한 사용자',
            isMe: false,
            isOwner: false,
            isWithdrawn: true,
            paidAmount: 0,
            shareAmount: 12000,
            netAmount: -12000,
          ),
        ];
    }
  }

  List<SettlementTransferItem> _createTransfers({
    required int currentParticipantId,
    required SettlementMockCase mockCase,
  }) {
    switch (mockCase) {
      case SettlementMockCase.memberNeedsToSend:
        return [
          SettlementTransferItem(
            id: 1,
            senderParticipantId: currentParticipantId,
            senderDisplayName: '나',
            receiverParticipantId: 22,
            receiverDisplayName: '민지',
            amount: 32000,
            currency: 'KRW',
            status: SettlementTransferStatus.pending,
            senderConfirmed: false,
            receiverConfirmed: false,
            autoConfirmed: false,
          ),
        ];
      case SettlementMockCase.ownerConfirmedMixed:
        return [
          SettlementTransferItem(
            id: 1,
            senderParticipantId: currentParticipantId,
            senderDisplayName: '나',
            receiverParticipantId: 22,
            receiverDisplayName: '민지',
            amount: 12000,
            currency: 'KRW',
            status: SettlementTransferStatus.pending,
            senderConfirmed: false,
            receiverConfirmed: false,
            autoConfirmed: false,
          ),
          const SettlementTransferItem(
            id: 2,
            senderParticipantId: 33,
            senderDisplayName: '현우',
            receiverParticipantId: 22,
            receiverDisplayName: '민지',
            amount: 34000,
            currency: 'KRW',
            status: SettlementTransferStatus.senderConfirmed,
            senderConfirmed: true,
            receiverConfirmed: false,
            autoConfirmed: false,
          ),
        ];
      case SettlementMockCase.allCompleted:
        return [
          SettlementTransferItem(
            id: 1,
            senderParticipantId: 22,
            senderDisplayName: '민지',
            receiverParticipantId: currentParticipantId,
            receiverDisplayName: '나',
            amount: 14000,
            currency: 'KRW',
            status: SettlementTransferStatus.completed,
            senderConfirmed: true,
            receiverConfirmed: true,
            autoConfirmed: false,
          ),
        ];
      case SettlementMockCase.noTransfers:
        return [];
      case SettlementMockCase.ownerNotStarted:
      case SettlementMockCase.ownerPreviewed:
      case SettlementMockCase.memberNeedsToReceive:
        return [
          SettlementTransferItem(
            id: 1,
            senderParticipantId: 22,
            senderDisplayName: '민지',
            receiverParticipantId: currentParticipantId,
            receiverDisplayName: '나',
            amount: 46860,
            currency: 'KRW',
            status: SettlementTransferStatus.pending,
            senderConfirmed: false,
            receiverConfirmed: false,
            autoConfirmed: false,
          ),
          const SettlementTransferItem(
            id: 2,
            senderParticipantId: 44,
            senderDisplayName: '탈퇴한 사용자',
            receiverParticipantId: 33,
            receiverDisplayName: '현우',
            amount: 12000,
            currency: 'KRW',
            status: SettlementTransferStatus.senderConfirmed,
            senderConfirmed: true,
            receiverConfirmed: false,
            autoConfirmed: true,
          ),
        ];
    }
  }
}
