import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../model/moderation_models.dart';
import '../service/moderation_service.dart';

Future<bool?> showReportSheet({
  required BuildContext context,
  required int tripId,
  required ReportTargetType targetType,
  required int targetId,
  required String targetLabel,
  required ModerationService moderationService,
}) {
  return showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReportSheet(
      tripId: tripId,
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
      moderationService: moderationService,
    ),
  );
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.tripId,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.moderationService,
  });

  final int tripId;
  final ReportTargetType targetType;
  final int targetId;
  final String targetLabel;
  final ModerationService moderationService;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _descriptionController = TextEditingController();
  ReportReason? _reason;
  bool _isSubmitting = false;
  bool _isCompleted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${widget.targetLabel} 신고'),
        content: const Text('선택한 내용으로 신고할까요? 신고 내용은 운영 정책에 따라 검토됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('confirmReportButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: AppButtonStyles.primary(),
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.moderationService.createReport(
        widget.tripId,
        ReportRequest(
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: reason,
          description: _descriptionController.text,
        ),
      );
      if (!mounted) return;
      setState(() => _isCompleted = true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '신고를 접수하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: AppMotion.fast,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _isCompleted ? _buildCompleted() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildCompleted() {
    return Semantics(
      liveRegion: true,
      label: '신고 접수 완료',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHandle(),
          const SizedBox(height: 24),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            '신고가 접수됐어요',
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            '운영 정책에 따라 확인하고 필요한 조치를 진행할게요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSubtle),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('reportCompleteButton'),
            onPressed: () => Navigator.of(context).pop(true),
            style: AppButtonStyles.primary(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHandle(),
          const SizedBox(height: 18),
          Text('${widget.targetLabel} 신고', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(
            '가장 가까운 사유를 선택해 주세요.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSubtle),
          ),
          const SizedBox(height: 12),
          ...ReportReason.values.map(
            (reason) => Semantics(
              label: '신고 사유 ${reason.label}',
              selected: _reason == reason,
              child: ListTile(
                key: ValueKey('reportReason-${reason.apiValue}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _reason == reason
                      ? AppColors.brand
                      : AppColors.textMuted,
                ),
                title: Text(reason.label),
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _reason = reason),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('reportDescriptionField'),
            controller: _descriptionController,
            enabled: !_isSubmitting,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: AppInputDecorations.filled(
              labelText: '추가 설명 (선택)',
              hintText: '운영자가 확인할 내용을 알려주세요.',
              alignLabelWithHint: true,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: AppErrorText(_errorMessage!)),
          ],
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: _isSubmitting ? '신고 접수 중' : '신고 내용 확인',
            child: FilledButton(
              key: const ValueKey('reportSubmitButton'),
              onPressed: _reason == null || _isSubmitting ? null : _submit,
              style: AppButtonStyles.primary(),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('신고하기'),
            ),
          ),
        ],
      ),
    );
  }
}
