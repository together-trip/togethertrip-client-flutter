import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../model/settlement_models.dart';

class SettlementBalanceCard extends StatelessWidget {
  final SettlementBalance balance;
  final String currency;

  const SettlementBalanceCard({
    super.key,
    required this.balance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final netLabel = balance.netAmount > 0
        ? '받을 돈'
        : balance.netAmount < 0
        ? '보낼 돈'
        : '정산 없음';
    final netAmount = balance.netAmount > 0
        ? balance.netAmount
        : balance.netAmount < 0
        ? -balance.netAmount
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: balance.isMe
                    ? AppColors.brandSoft
                    : AppColors.neutralSoft,
                child: Text(
                  balance.isWithdrawn
                      ? '탈'
                      : balance.displayName.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  balance.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (balance.isMe) const _Badge(label: '나'),
              if (balance.isOwner) const SizedBox(width: 4),
              if (balance.isOwner) const _Badge(label: '방장'),
            ],
          ),
          const SizedBox(height: 10),
          _AmountRow(
            label: '결제한 금액',
            value: formatSettlementAmount(balance.paidAmount, currency),
          ),
          _AmountRow(
            label: '소비한 금액',
            value: formatSettlementAmount(balance.shareAmount, currency),
          ),
          _AmountRow(
            label: netLabel,
            value: formatSettlementAmount(netAmount, currency),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.brandStrong,
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
