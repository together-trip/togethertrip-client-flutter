import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../model/moderation_models.dart';
import '../service/moderation_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, this.moderationService});

  final ModerationService? moderationService;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final ModerationService _service;
  List<BlockedUser> _users = const [];
  final Set<int> _unblockingUserIds = {};
  bool _isLoading = true;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.moderationService ?? ModerationService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await _service.getBlockedUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '차단 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_unblockingUserIds.contains(user.blockedUserId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('${user.displayName}님의 일반 기록과 댓글을 다시 표시할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('차단 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unblockingUserIds.add(user.blockedUserId));
    try {
      await _service.unblockUser(user.blockedUserId);
      if (!mounted) return;
      setState(() {
        _users = _users
            .where((item) => item.blockedUserId != user.blockedUserId)
            .toList();
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제했습니다.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제하지 못했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _unblockingUserIds.remove(user.blockedUserId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('차단한 사용자')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppErrorText(_errorMessage!, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('다시 시도')),
                    ],
                  ),
                ),
              )
            : _users.isEmpty
            ? const Center(child: Text('차단한 사용자가 없습니다.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _users.length + 1,
                separatorBuilder: (_, _) =>
                    const Divider(color: AppColors.lineSoft),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '차단한 사용자의 일반 기록과 댓글은 숨겨집니다. 지출·정산 정보는 정확한 금액 계산을 위해 계속 표시됩니다.',
                        style: AppTextStyles.caption.copyWith(height: 1.5),
                      ),
                    );
                  }
                  final user = _users[index - 1];
                  final isBusy = _unblockingUserIds.contains(
                    user.blockedUserId,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Semantics(
                      button: true,
                      label: '${user.displayName} 차단 해제',
                      child: OutlinedButton(
                        key: ValueKey('unblockUser-${user.blockedUserId}'),
                        onPressed: isBusy ? null : () => _unblock(user),
                        child: Text(isBusy ? '처리 중…' : '차단 해제'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
