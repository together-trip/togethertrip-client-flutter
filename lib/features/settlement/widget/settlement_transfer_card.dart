import 'package:flutter/material.dart';

import '../model/settlement_models.dart';

class SettlementTransferCard extends StatelessWidget {
  final SettlementTransferItem transfer;
  final SettlementTransferDirection direction;
  final bool canConfirm;
  final VoidCallback onConfirm;

  const SettlementTransferCard({
    super.key,
    required this.transfer,
    required this.direction,
    required this.canConfirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isSent = direction == SettlementTransferDirection.sent;
    final targetName = isSent
        ? '${transfer.receiverDisplayName}에게'
        : '${transfer.senderDisplayName}에게서';
    final actionLabel = isSent ? '송금 완료' : '수금 완료';
    final doneByMe = isSent
        ? transfer.senderConfirmed
        : transfer.receiverConfirmed;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A1A1A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFF2F2F2),
            child: Text(
              targetName.substring(0, 1),
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatSettlementAmount(transfer.amount, transfer.currency)} ${_statusText(doneByMe)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                if (transfer.autoConfirmed) ...[
                  const SizedBox(height: 3),
                  const Text(
                    '탈퇴 사용자 자동 확인됨',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            onPressed: canConfirm && !doneByMe && !transfer.isCompleted
                ? onConfirm
                : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: canConfirm && !doneByMe && !transfer.isCompleted
                  ? const Color(0xFF1A1A1A)
                  : Colors.white,
              foregroundColor: canConfirm && !doneByMe && !transfer.isCompleted
                  ? Colors.white
                  : const Color(0xFF9E9E9E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              transfer.isCompleted
                  ? '완료됨'
                  : doneByMe
                  ? '확인됨'
                  : actionLabel,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(bool doneByMe) {
    if (transfer.isCompleted) return '완료됨';
    if (doneByMe) return '상대 확인 대기';
    return direction == SettlementTransferDirection.sent ? '보내기' : '받기';
  }
}
