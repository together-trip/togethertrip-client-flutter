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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '정산 상태',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSubtle,
                      ),
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
          if (overview.stage == SettlementStage.confirmed) ...[
            const SizedBox(height: 14),
            _SettlementProgress(overview: overview),
          ],
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

class _SettlementProgress extends StatelessWidget {
  final SettlementOverview overview;

  const _SettlementProgress({required this.overview});

  @override
  Widget build(BuildContext context) {
    final total = overview.totalTransferCount;
    if (total == 0) {
      return const Text(
        '전체 정산 현황 · 확인할 송금이 없어요',
        style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: overview.overallConfirmationProgress.clamp(0, 1).toDouble(),
            backgroundColor: AppColors.line,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              '전체 정산 현황',
              style: _progressTextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '송금 확인 ${overview.senderConfirmedTransferCount}/$total',
              style: _progressTextStyle(),
            ),
            Text(
              '수금 확인 ${overview.receiverConfirmedTransferCount}/$total',
              style: _progressTextStyle(),
            ),
            Text(
              '완료 ${overview.completedTransferCount}/$total',
              style: _progressTextStyle(),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _progressTextStyle({FontWeight fontWeight = FontWeight.w600}) {
    return TextStyle(
      fontSize: 11,
      fontWeight: fontWeight,
      color: AppColors.textSubtle,
    );
  }
}
