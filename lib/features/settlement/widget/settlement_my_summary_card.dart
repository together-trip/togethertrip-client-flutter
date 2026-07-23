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
          const Text(
            '내가 확인할 정산',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
