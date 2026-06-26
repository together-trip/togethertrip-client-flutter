import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../model/settlement_models.dart';

class SettlementStatusSummary extends StatelessWidget {
  final SettlementOverview overview;
  final bool isBusy;
  final VoidCallback onPrimaryAction;
  final VoidCallback onShare;

  const SettlementStatusSummary({
    super.key,
    required this.overview,
    required this.isBusy,
    required this.onPrimaryAction,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabel = _primaryLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정산 상태',
                  style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          if (overview.stage == SettlementStage.confirmed)
            OutlinedButton(
              key: const ValueKey('shareSettlementButton'),
              onPressed: isBusy ? null : onShare,
              child: Text(overview.shareToken == null ? '공유' : '공유됨'),
            )
          else if (overview.isOwner && primaryLabel != null)
            ElevatedButton(
              key: const ValueKey('settlementPrimaryButton'),
              onPressed: isBusy ? null : onPrimaryAction,
              style: AppButtonStyles.elevatedPrimary(),
              child: Text(primaryLabel),
            ),
        ],
      ),
    );
  }

  String? get _primaryLabel {
    switch (overview.stage) {
      case SettlementStage.notStarted:
        return '정산 미리보기';
      case SettlementStage.previewed:
        return '정산하기';
      case SettlementStage.confirmed:
        return null;
    }
  }

  String get _statusLabel {
    switch (overview.stage) {
      case SettlementStage.notStarted:
        return '정산 미시작';
      case SettlementStage.previewed:
        return '미리보기 완료';
      case SettlementStage.confirmed:
        return overview.allTransfersCompleted ? '정산 완료' : '확인할 정산 있음';
    }
  }

  String get _statusDescription {
    switch (overview.stage) {
      case SettlementStage.notStarted:
        return overview.isOwner ? '현재 지출 기준으로 먼저 확인해요' : '방장이 정산을 시작할 수 있어요';
      case SettlementStage.previewed:
        return overview.isOwner ? '확정하면 되돌릴 수 없어요' : '현재 기준 정산 결과예요';
      case SettlementStage.confirmed:
        if (overview.hasPendingSentTransfers) {
          return '보낼 돈의 송금 확인이 필요해요';
        }
        if (overview.hasPendingReceivedTransfers) {
          return '받을 돈의 수금 확인이 필요해요';
        }
        return overview.allTransfersCompleted
            ? '모든 송금과 수금 확인이 끝났어요'
            : '동행자의 확인을 기다리고 있어요';
    }
  }
}
