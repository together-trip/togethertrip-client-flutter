import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widget/app_design.dart';

/// 확정 정산의 공유 링크를 보여주고 복사와 재발급을 제공한다.
class SettlementShareSheet extends StatelessWidget {
  final String shareLink;
  final bool isBusy;
  final Future<void> Function() onRotate;

  const SettlementShareSheet({
    super.key,
    required this.shareLink,
    required this.isBusy,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSheetHandle(),
              const SizedBox(height: 18),
              const Text(
                '정산 공유 링크',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '링크를 가진 사람은 누구나 정산 결과를 볼 수 있어요. 아무나 볼 수 있는 곳에 올리지 말아주세요.',
                style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(shareLink, style: AppTextStyles.body),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey('copySettlementShareLinkButton'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: shareLink));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공유 링크를 복사했어요.')),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('링크 복사'),
                style: AppButtonStyles.elevatedPrimary(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('rotateSettlementShareLinkButton'),
                onPressed: isBusy ? null : () => _confirmRotate(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('새 링크 발급'),
              ),
              const SizedBox(height: 8),
              const Text(
                '새 링크를 발급하면 지금 링크는 더 이상 열리지 않아요.',
                style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRotate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 링크 발급'),
          content: const Text('지금 링크는 더 이상 열리지 않아요. 계속할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('confirmRotateShareLinkButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: AppButtonStyles.primary(),
              child: const Text('발급'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    Navigator.of(context).pop();
    await onRotate();
  }
}
