import 'package:flutter/material.dart';

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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정산 상태',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B6B6B),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
        return overview.allTransfersCompleted ? '정산 완료' : '송금 확인 중';
    }
  }

  String get _statusDescription {
    switch (overview.stage) {
      case SettlementStage.notStarted:
        return overview.isOwner ? '현재 지출 기준으로 먼저 확인해요' : '방장이 정산을 시작할 수 있어요';
      case SettlementStage.previewed:
        return overview.isOwner ? '확정하면 되돌릴 수 없어요' : '현재 기준 정산 결과예요';
      case SettlementStage.confirmed:
        return '확정된 결과를 기준으로 확인해요';
    }
  }
}
