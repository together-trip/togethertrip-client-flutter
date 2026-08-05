import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../model/settlement_models.dart';

class SettlementMySummaryCard extends StatelessWidget {
  final SettlementOverview overview;

  const SettlementMySummaryCard({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final balance = overview.currentBalance;
    final sentDone = overview.sentTransfers
        .where((item) => item.senderConfirmed)
        .length;
    final receivedDone = overview.receivedTransfers
        .where((item) => item.receiverConfirmed)
        .length;
    final pendingReceived = overview.receivedTransfers
        .where((item) => !item.isCompleted && !item.receiverConfirmed)
        .length;
    final pendingSent = overview.sentTransfers
        .where((item) => !item.isCompleted && !item.senderConfirmed)
        .length;
    final canConfirmTransfers = overview.stage == SettlementStage.confirmed;
    final hasReceiveTask = canConfirmTransfers && pendingReceived > 0;
    final hasSendTask = canConfirmTransfers && pendingSent > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasReceiveTask
                ? '받을 돈을 확인해주세요'
                : hasSendTask
                ? '보낼 돈을 확인해주세요'
                : '내 정산 현황',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            hasReceiveTask
                ? '수금 확인 $pendingReceived건이 남아 있어요.'
                : hasSendTask
                ? '송금 확인 $pendingSent건이 남아 있어요.'
                : '보낼 돈과 받을 돈을 한눈에 확인하세요.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '받을 돈',
                  value: formatSettlementAmount(
                    balance.receiveAmount,
                    overview.baseCurrency,
                  ),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '보낼 돈',
                  value: formatSettlementAmount(
                    balance.sendAmount,
                    overview.baseCurrency,
                  ),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '확인 필요',
                  value:
                      '$sentDone/${overview.sentTransfers.length} · $receivedDone/${overview.receivedTransfers.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
