import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../trip/screen/trip_detail_screen.dart';
import '../../trip/screen/trip_recap_screen.dart';
import '../../trip/service/trip_service.dart';
import '../service/notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  final NotificationService? notificationService;
  final TripService? tripService;

  const NotificationListScreen({
    super.key,
    this.notificationService,
    this.tripService,
  });

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationService _notificationService;
  late final TripService _tripService;

  List<AppNotification> _notifications = const [];
  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService();
    _tripService = widget.tripService ?? TripService();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await _notificationService.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '알림을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAll || _notifications.every((item) => item.isRead)) return;

    setState(() {
      _isMarkingAll = true;
      _errorMessage = null;
    });

    try {
      await _notificationService.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.isRead ? item : item.copyWith(readAt: 'read'))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '알림 읽음 처리에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    AppNotification current = notification;

    if (!notification.isRead) {
      try {
        current = await _notificationService.markAsRead(notification.id);
        if (!mounted) return;
        setState(() {
          _notifications = _notifications
              .map((item) => item.id == current.id ? current : item)
              .toList();
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _errorMessage = e.message);
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorMessage = '알림 읽음 처리에 실패했습니다: $e');
        return;
      }
    }

    final target = NotificationDeepLinkTarget.parse(current.deeplink);
    if (target == null) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => target.isRecap
            ? TripRecapScreen(
                tripId: target.tripId,
                tripRecapId: target.recapId,
                tripService: _tripService,
              )
            : TripDetailScreen(
                tripId: target.tripId,
                tripService: _tripService,
                onClose: (_) => Navigator.of(context).pop(),
              ),
      ),
    );
  }

  Future<bool> _deleteNotification(AppNotification notification) async {
    try {
      await _notificationService.deleteNotification(notification.id);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 삭제에 실패했습니다: $e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((item) => !item.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left, size: 24),
          color: AppColors.ink,
          tooltip: '뒤로',
        ),
        title: const Text('알림', style: AppTextStyles.screenTitle),
        actions: [
          TextButton(
            onPressed: _isMarkingAll || unreadCount == 0
                ? null
                : _markAllAsRead,
            child: _isMarkingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('모두 읽음'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: _buildBody(unreadCount),
        ),
      ),
    );
  }

  Widget _buildBody(int unreadCount) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
        children: [
          const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _loadNotifications,
              style: AppButtonStyles.inkText(),
              child: const Text('다시 시도'),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
        children: const [
          Icon(Icons.notifications_none, size: 36, color: AppColors.textSubtle),
          SizedBox(height: 14),
          Text(
            '새 알림이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '초대, 정산, 여행 변경 알림이 생기면 여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _notifications.length + 1,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              unreadCount == 0 ? '모든 알림을 확인했습니다.' : '읽지 않은 알림 $unreadCount개',
              style: AppTextStyles.caption,
            ),
          );
        }

        final notificationIndex = index - 1;
        final notification = _notifications[notificationIndex];
        final dateLabel = _dateGroupLabel(
          notification.occurredAt ?? notification.createdAt,
        );
        final previousLabel = notificationIndex == 0
            ? null
            : _dateGroupLabel(
                _notifications[notificationIndex - 1].occurredAt ??
                    _notifications[notificationIndex - 1].createdAt,
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dateLabel != previousLabel)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  4,
                  notificationIndex == 0 ? 8 : 24,
                  4,
                  4,
                ),
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Dismissible(
              key: ValueKey('notification-${notification.id}'),
              direction: DismissDirection.endToStart,
              background: const _DeleteNotificationBackground(),
              confirmDismiss: (_) => _deleteNotification(notification),
              onDismissed: (_) {
                setState(() {
                  _notifications = _notifications
                      .where((item) => item.id != notification.id)
                      .toList();
                });
              },
              child: _NotificationTile(
                notification: notification,
                onTap: () => _openNotification(notification),
              ),
            ),
          ],
        );
      },
    );
  }

  String _dateGroupLabel(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return '이전 알림';
    final now = DateTime.now();
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    return '${parsed.month}월 ${parsed.day}일';
  }
}

class _DeleteNotificationBackground extends StatelessWidget {
  const _DeleteNotificationBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.danger,
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                notification.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                size: 22,
                color: notification.isRead
                    ? AppColors.textMuted
                    : AppColors.brandStrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _displayTime(
                      notification.occurredAt ?? notification.createdAt,
                    ),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}

class NotificationDeepLinkTarget {
  final int tripId;
  final int? recapId;

  const NotificationDeepLinkTarget({required this.tripId, this.recapId});

  bool get isRecap => recapId != null;

  static NotificationDeepLinkTarget? parse(String? value) {
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'togethertrip') return null;

    final segments = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments];
    final tripIndex = segments.indexOf('trips');
    if (tripIndex < 0 || tripIndex + 1 >= segments.length) return null;

    final tripId = int.tryParse(segments[tripIndex + 1]);
    if (tripId == null) return null;

    final recapIndex = segments.indexOf('recap');
    final recapId = recapIndex >= 0 && recapIndex + 1 < segments.length
        ? int.tryParse(segments[recapIndex + 1])
        : null;

    return NotificationDeepLinkTarget(tripId: tripId, recapId: recapId);
  }
}
