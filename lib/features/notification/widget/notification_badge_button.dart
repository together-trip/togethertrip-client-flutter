import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../service/notification_service.dart';

class NotificationBadgeButton extends StatefulWidget {
  final FutureOr<void> Function() onPressed;
  final NotificationService? notificationService;
  final Key? buttonKey;

  const NotificationBadgeButton({
    super.key,
    required this.onPressed,
    this.notificationService,
    this.buttonKey,
  });

  @override
  State<NotificationBadgeButton> createState() =>
      _NotificationBadgeButtonState();
}

class _NotificationBadgeButtonState extends State<NotificationBadgeButton> {
  late final NotificationService _notificationService;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.countUnreadNotifications();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadCount = 0);
    }
  }

  Future<void> _handlePressed() async {
    await widget.onPressed();
    if (!mounted) return;
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: widget.buttonKey,
      onPressed: _handlePressed,
      icon: _NotificationBellIcon(unreadCount: _unreadCount),
      color: AppColors.ink,
      tooltip: '알림',
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  final int unreadCount;

  const _NotificationBellIcon({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.notifications_none_rounded, size: 22),
          ),
          if (hasUnread)
            Positioned(
              top: 1,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
