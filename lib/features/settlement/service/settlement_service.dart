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
  SettlementOverview? _overview;

  Future<SettlementOverview> getOverview({
    required int tripId,
    required String tripTitle,
    required bool isOwner,
    required int currentParticipantId,
    SettlementMockCase mockCase = SettlementMockCase.ownerNotStarted,
    bool reset = false,
  }) async {
    if (_overview == null || reset) {
      _overview = _createMockOverview(
        tripId: tripId,
        tripTitle: tripTitle,
        isOwner: isOwner,
        currentParticipantId: currentParticipantId,
        mockCase: mockCase,
      );
    }
    return _overview!;
  }

  Future<SettlementOverview> previewSettlement() async {
    final current = _requireOverview();
    _overview = current.copyWith(stage: SettlementStage.previewed);
    return _overview!;
  }

  Future<SettlementOverview> confirmSettlement() async {
    final current = _requireOverview();
    _overview = current.copyWith(
      stage: SettlementStage.confirmed,
      settlementId: 901,
    );
    return _overview!;
  }

  Future<SettlementOverview> createShareToken() async {
    final current = _requireOverview();
    _overview = current.copyWith(shareToken: 'mock-share-token');
    return _overview!;
  }

  Future<SettlementOverview> confirmTransferAsSender(int transferId) async {
    final current = _requireOverview();
    _overview = current.copyWith(
      transfers: current.transfers.map((transfer) {
        if (transfer.id != transferId) return transfer;
        return transfer.confirmSender();
      }).toList(),
    );
    return _overview!;
  }

  Future<SettlementOverview> confirmTransferAsReceiver(int transferId) async {
    final current = _requireOverview();
    _overview = current.copyWith(
      transfers: current.transfers.map((transfer) {
        if (transfer.id != transferId) return transfer;
        return transfer.confirmReceiver();
      }).toList(),
    );
    return _overview!;
  }

  SettlementOverview _requireOverview() {
    final overview = _overview;
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
    final balances = _createBalances(
      currentParticipantId: currentParticipantId,
      isOwner: effectiveIsOwner,
      mockCase: mockCase,
    );
    final transfers = _createTransfers(
      currentParticipantId: currentParticipantId,
      mockCase: mockCase,
    );

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
      balances: balances,
      transfers: transfers,
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
