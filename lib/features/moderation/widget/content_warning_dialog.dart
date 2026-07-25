import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../service/content_warning_detector.dart';

const _contentWarningDetector = ContentWarningDetector();

Future<bool> confirmPotentiallyOffensiveContent(
  BuildContext context,
  Iterable<String?> values,
) async {
  if (!_contentWarningDetector.containsPotentiallyOffensiveContent(values)) {
    return true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('표현을 한 번 확인해주세요'),
      content: const Text('부적절한 표현으로 오해될 수 있는 내용이 포함되어 있어요. 그래도 등록할까요?'),
      actions: [
        TextButton(
          key: const ValueKey('editPotentiallyOffensiveContentButton'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('수정하기'),
        ),
        FilledButton(
          key: const ValueKey('submitPotentiallyOffensiveContentButton'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: AppButtonStyles.primary(),
          child: const Text('그대로 등록'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
