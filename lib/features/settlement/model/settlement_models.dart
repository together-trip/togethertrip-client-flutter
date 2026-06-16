enum SettlementStage { notStarted, previewed, confirmed }

enum SettlementTransferStatus {
  pending,
  senderConfirmed,
  receiverConfirmed,
  completed,
  cancelled,
}

enum SettlementTransferDirection { sent, received }

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
