import 'package:flutter/material.dart';

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
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 정산 요약',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
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
                  label: '확인',
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
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
