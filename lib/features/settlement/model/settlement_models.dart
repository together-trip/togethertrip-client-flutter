enum SettlementStage { notStarted, previewed, confirmed }

enum SettlementTransferStatus {
  pending,
  senderConfirmed,
  receiverConfirmed,
  completed,
  cancelled,
}

enum SettlementTransferDirection { sent, received }

enum SettlementSourceStatus { notStarted, settled }

class SettlementOverview {
  final int tripId;
  final String tripTitle;
  final String baseCurrency;
  final SettlementStage stage;
  final int currentParticipantId;
  final bool isOwner;
  final int? settlementId;
  final String? shareToken;
  final List<SettlementBalance> balances;
  final List<SettlementTransferItem> transfers;

  const SettlementOverview({
    required this.tripId,
    required this.tripTitle,
    required this.baseCurrency,
    required this.stage,
    required this.currentParticipantId,
    required this.isOwner,
    required this.settlementId,
    required this.shareToken,
    required this.balances,
    required this.transfers,
  });

  SettlementBalance get currentBalance {
    return balances.firstWhere(
      (balance) => balance.participantId == currentParticipantId,
      orElse: () => SettlementBalance.empty(currentParticipantId),
    );
  }

  List<SettlementTransferItem> get sentTransfers {
    return transfers
        .where(
          (transfer) => transfer.senderParticipantId == currentParticipantId,
        )
        .toList();
  }

  List<SettlementTransferItem> get receivedTransfers {
    return transfers
        .where(
          (transfer) => transfer.receiverParticipantId == currentParticipantId,
        )
        .toList();
  }

  bool get allTransfersCompleted {
    return transfers.every((transfer) => transfer.isCompleted);
  }

  SettlementOverview copyWith({
    SettlementStage? stage,
    int? settlementId,
    String? shareToken,
    List<SettlementBalance>? balances,
    List<SettlementTransferItem>? transfers,
  }) {
    return SettlementOverview(
      tripId: tripId,
      tripTitle: tripTitle,
      baseCurrency: baseCurrency,
      stage: stage ?? this.stage,
      currentParticipantId: currentParticipantId,
      isOwner: isOwner,
      settlementId: settlementId ?? this.settlementId,
      shareToken: shareToken ?? this.shareToken,
      balances: balances ?? this.balances,
      transfers: transfers ?? this.transfers,
    );
  }

  factory SettlementOverview.fromBalanceSummaryJson({
    required Map<String, dynamic> json,
    required String tripTitle,
    required int currentParticipantId,
    required bool isOwner,
    required SettlementSourceStatus sourceStatus,
    List<SettlementTransferItem> transfers = const [],
  }) {
    return SettlementOverview(
      tripId: (json['tripId'] as num).toInt(),
      tripTitle: tripTitle,
      baseCurrency: json['baseCurrency'] as String? ?? 'KRW',
      stage: sourceStatus == SettlementSourceStatus.settled
          ? SettlementStage.confirmed
          : SettlementStage.notStarted,
      currentParticipantId: currentParticipantId,
      isOwner: isOwner,
      settlementId: null,
      shareToken: null,
      balances: _parseBalances(
        json['balances'],
        currentParticipantId: currentParticipantId,
        ownerParticipantId: null,
      ),
      transfers: transfers,
    );
  }

  factory SettlementOverview.fromPreviewJson({
    required Map<String, dynamic> json,
    required String tripTitle,
    required int currentParticipantId,
    required bool isOwner,
  }) {
    return SettlementOverview(
      tripId: (json['tripId'] as num).toInt(),
      tripTitle: tripTitle,
      baseCurrency: json['baseCurrency'] as String? ?? 'KRW',
      stage: SettlementStage.previewed,
      currentParticipantId: currentParticipantId,
      isOwner: isOwner,
      settlementId: null,
      shareToken: null,
      balances: _parseBalances(
        json['balances'],
        currentParticipantId: currentParticipantId,
        ownerParticipantId: null,
      ),
      transfers: _parseTransfers(json['transfers']),
    );
  }

  factory SettlementOverview.fromSettlementJson({
    required Map<String, dynamic> json,
    required String tripTitle,
    required int currentParticipantId,
    required bool isOwner,
    String? shareToken,
  }) {
    return SettlementOverview(
      tripId: (json['tripId'] as num).toInt(),
      tripTitle: tripTitle,
      baseCurrency: json['baseCurrency'] as String? ?? 'KRW',
      stage: _stageFromStatus(json['status'] as String?),
      currentParticipantId: currentParticipantId,
      isOwner: isOwner,
      settlementId: (json['id'] as num?)?.toInt(),
      shareToken: shareToken,
      balances: _parseBalances(
        json['balances'],
        currentParticipantId: currentParticipantId,
        ownerParticipantId: null,
      ),
      transfers: _parseTransfers(json['transfers']),
    );
  }
}

class SettlementBalance {
  final int participantId;
  final String displayName;
  final bool isMe;
  final bool isOwner;
  final bool isWithdrawn;
  final int paidAmount;
  final int shareAmount;
  final int netAmount;

  const SettlementBalance({
    required this.participantId,
    required this.displayName,
    required this.isMe,
    required this.isOwner,
    required this.isWithdrawn,
    required this.paidAmount,
    required this.shareAmount,
    required this.netAmount,
  });

  factory SettlementBalance.empty(int participantId) {
    return SettlementBalance(
      participantId: participantId,
      displayName: '나',
      isMe: true,
      isOwner: false,
      isWithdrawn: false,
      paidAmount: 0,
      shareAmount: 0,
      netAmount: 0,
    );
  }

  factory SettlementBalance.fromJson(
    Map<String, dynamic> json, {
    required int currentParticipantId,
    required int? ownerParticipantId,
  }) {
    final participantId = (json['participantId'] as num).toInt();
    final participantStatus = json['participantStatus'] as String? ?? 'ACTIVE';
    return SettlementBalance(
      participantId: participantId,
      displayName: json['displayName'] as String? ?? '알 수 없음',
      isMe: participantId == currentParticipantId,
      isOwner:
          ownerParticipantId != null && participantId == ownerParticipantId,
      isWithdrawn: participantStatus != 'ACTIVE',
      paidAmount: _amountToInt(json['paidAmount']),
      shareAmount: _amountToInt(json['shareAmount']),
      netAmount: _amountToInt(json['netAmount']),
    );
  }

  int get receiveAmount => netAmount > 0 ? netAmount : 0;
  int get sendAmount => netAmount < 0 ? -netAmount : 0;
}

class SettlementTransferItem {
  final int id;
  final int senderParticipantId;
  final String senderDisplayName;
  final int receiverParticipantId;
  final String receiverDisplayName;
  final int amount;
  final String currency;
  final SettlementTransferStatus status;
  final bool senderConfirmed;
  final bool receiverConfirmed;
  final bool autoConfirmed;

  const SettlementTransferItem({
    required this.id,
    required this.senderParticipantId,
    required this.senderDisplayName,
    required this.receiverParticipantId,
    required this.receiverDisplayName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.senderConfirmed,
    required this.receiverConfirmed,
    required this.autoConfirmed,
  });

  bool get isCompleted => status == SettlementTransferStatus.completed;

  SettlementTransferItem confirmSender() {
    final nextReceiverConfirmed = receiverConfirmed;
    return copyWith(
      senderConfirmed: true,
      status: nextReceiverConfirmed
          ? SettlementTransferStatus.completed
          : SettlementTransferStatus.senderConfirmed,
    );
  }

  SettlementTransferItem confirmReceiver() {
    final nextSenderConfirmed = senderConfirmed;
    return copyWith(
      receiverConfirmed: true,
      status: nextSenderConfirmed
          ? SettlementTransferStatus.completed
          : SettlementTransferStatus.receiverConfirmed,
    );
  }

  SettlementTransferItem copyWith({
    SettlementTransferStatus? status,
    bool? senderConfirmed,
    bool? receiverConfirmed,
    bool? autoConfirmed,
  }) {
    return SettlementTransferItem(
      id: id,
      senderParticipantId: senderParticipantId,
      senderDisplayName: senderDisplayName,
      receiverParticipantId: receiverParticipantId,
      receiverDisplayName: receiverDisplayName,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      senderConfirmed: senderConfirmed ?? this.senderConfirmed,
      receiverConfirmed: receiverConfirmed ?? this.receiverConfirmed,
      autoConfirmed: autoConfirmed ?? this.autoConfirmed,
    );
  }

  factory SettlementTransferItem.fromJson(Map<String, dynamic> json) {
    final status = _transferStatusFromJson(json['status'] as String?);
    final senderConfirmedAt = json['senderConfirmedAt'] as String?;
    final receiverConfirmedAt = json['receiverConfirmedAt'] as String?;
    return SettlementTransferItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderParticipantId: (json['senderParticipantId'] as num).toInt(),
      senderDisplayName: json['senderDisplayName'] as String? ?? '알 수 없음',
      receiverParticipantId: (json['receiverParticipantId'] as num).toInt(),
      receiverDisplayName: json['receiverDisplayName'] as String? ?? '알 수 없음',
      amount: _amountToInt(json['amount']),
      currency: json['currency'] as String? ?? 'KRW',
      status: status,
      senderConfirmed:
          senderConfirmedAt != null ||
          status == SettlementTransferStatus.senderConfirmed ||
          status == SettlementTransferStatus.completed,
      receiverConfirmed:
          receiverConfirmedAt != null ||
          status == SettlementTransferStatus.receiverConfirmed ||
          status == SettlementTransferStatus.completed,
      autoConfirmed: false,
    );
  }
}

SettlementStage _stageFromStatus(String? status) {
  return switch (status) {
    'CONFIRMED' => SettlementStage.confirmed,
    _ => SettlementStage.previewed,
  };
}

SettlementTransferStatus _transferStatusFromJson(String? status) {
  return switch (status) {
    'SENDER_CONFIRMED' => SettlementTransferStatus.senderConfirmed,
    'RECEIVER_CONFIRMED' => SettlementTransferStatus.receiverConfirmed,
    'COMPLETED' => SettlementTransferStatus.completed,
    'CANCELLED' => SettlementTransferStatus.cancelled,
    _ => SettlementTransferStatus.pending,
  };
}

List<SettlementBalance> _parseBalances(
  dynamic value, {
  required int currentParticipantId,
  required int? ownerParticipantId,
}) {
  return (value as List<dynamic>? ?? const [])
      .map(
        (item) => SettlementBalance.fromJson(
          item as Map<String, dynamic>,
          currentParticipantId: currentParticipantId,
          ownerParticipantId: ownerParticipantId,
        ),
      )
      .toList();
}

List<SettlementTransferItem> _parseTransfers(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map(
        (item) => SettlementTransferItem.fromJson(item as Map<String, dynamic>),
      )
      .toList();
}

int _amountToInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    return (double.tryParse(value) ?? 0).round();
  }
  return 0;
}

String formatSettlementAmount(int amount, String currency) {
  final sign = amount < 0 ? '-' : '';
  final value = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index += 1) {
    final remaining = value.length - index;
    buffer.write(value[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  final symbol = currency == 'KRW' ? '원' : currency;
  return '$sign${buffer.toString()}$symbol';
}
