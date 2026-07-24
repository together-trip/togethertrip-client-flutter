import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../../../core/network/api_client.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../../notification/widget/notification_badge_button.dart';
import '../service/trip_service.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';

class TripListScreen extends StatefulWidget {
  final TripService? tripService;
  final ValueChanged<TripSummary>? onOpenTripDetail;

  const TripListScreen({super.key, this.tripService, this.onOpenTripDetail});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late final TripService _tripService;

  final List<TripSummary> _trips = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextCursor;
  bool _hasNext = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await _tripService.getTrips();
      if (!mounted) return;
      setState(() {
        _trips
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 목록을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNext || _nextCursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await _tripService.getTrips(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _trips.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '추가 여행을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<TripDetail>(
      MaterialPageRoute<TripDetail>(
        builder: (_) => TripFormScreen(tripService: _tripService),
      ),
    );

    if (created != null) {
      await _loadTrips();
      if (!mounted) return;
      await _openDetail(created.toSummary());
    }
  }

  Future<void> _openNotifications() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationListScreen(tripService: _tripService),
      ),
    );
  }

  Future<void> _openJoinByInviteCode() async {
    final joinedTripId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JoinByInviteCodeDialog(tripService: _tripService),
    );

    if (joinedTripId == null || !mounted) return;
    await _loadTrips();
    if (!mounted) return;
    await _openDetail(
      _findTripSummary(joinedTripId) ?? _fallbackTripSummary(joinedTripId),
    );
  }

  TripSummary? _findTripSummary(int tripId) {
    for (final trip in _trips) {
      if (trip.id == tripId) return trip;
    }
    return null;
  }

  TripSummary _fallbackTripSummary(int tripId) {
    return TripSummary(
      id: tripId,
      title: '초대 여행',
      defaultCurrency: 'KRW',
      startDate: null,
      endDate: null,
      tripStatus: 'PLANNED',
      settlementStatus: 'NOT_STARTED',
      settlementDisplayStatus: 'NOT_STARTED',
      ownerUserId: 0,
    );
  }

  Future<void> _openDetail(TripSummary trip) async {
    final onOpenTripDetail = widget.onOpenTripDetail;
    if (onOpenTripDetail != null) {
      onOpenTripDetail(trip);
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            TripDetailScreen(tripId: trip.id, tripService: _tripService),
      ),
    );

    if (changed == true) {
      await _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '여행',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        actions: [
          NotificationBadgeButton(
            buttonKey: const ValueKey('notificationButton'),
            onPressed: _openNotifications,
          ),
          IconButton(
            key: const ValueKey('joinTripByInviteCodeButton'),
            onPressed: _openJoinByInviteCode,
            icon: const Icon(Icons.key_rounded, size: 21),
            color: AppColors.ink,
            tooltip: '초대로 여행 참여',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const ValueKey('createTripButton'),
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 24),
              color: AppColors.ink,
              tooltip: '여행 만들기',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadTrips, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_errorMessage != null && _trips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        children: [
          const Text(
            '여행을 불러오지 못했습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: _loadTrips, child: const Text('다시 시도')),
        ],
      );
    }

    if (_trips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
        children: [
          const Text(
            '아직 표시할 여행이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '함께 떠날 여행을 만들고 동행자를 기록해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _openCreate,
            style: AppButtonStyles.elevatedPrimary(),
            child: const Text('첫 여행 만들기'),
          ),
        ],
      );
    }

    final ongoingTrips = _trips
        .where((trip) => trip.tripStatus == 'ONGOING')
        .toList();
    final plannedTrips = _trips
        .where((trip) => trip.tripStatus == 'PLANNED')
        .toList();
    final completedTrips = _trips
        .where((trip) => trip.tripStatus == 'COMPLETED')
        .toList();
    final currentTrip = ongoingTrips.isEmpty ? null : ongoingTrips.first;
    final remainingTrips = [...ongoingTrips.skip(1), ...plannedTrips];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      children: [
        if (currentTrip != null) ...[
          _CurrentTripCover(trip: currentTrip, onTap: _openDetail),
          const SizedBox(height: 28),
        ],
        if (currentTrip == null) ...[
          _TripStartBanner(onCreate: _openCreate),
          const SizedBox(height: 28),
        ],
        if (remainingTrips.isNotEmpty) ...[
          const _TripSectionTitle(title: '다음 여행'),
          const SizedBox(height: 8),
          ...remainingTrips.map(
            (trip) => _TripListRow(trip: trip, onTap: _openDetail),
          ),
        ],
        if (completedTrips.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _TripSectionTitle(title: '지난 여행'),
          const SizedBox(height: 8),
          ...completedTrips.map(
            (trip) => _TripListRow(trip: trip, onTap: _openDetail),
          ),
        ],
        if (_hasNext) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isLoadingMore ? null : _loadMore,
            child: Text(_isLoadingMore ? '불러오는 중...' : '더 보기'),
          ),
        ],
      ],
    );
  }
}

class _JoinByInviteCodeDialog extends StatefulWidget {
  final TripService tripService;

  const _JoinByInviteCodeDialog({required this.tripService});

  @override
  State<_JoinByInviteCodeDialog> createState() =>
      _JoinByInviteCodeDialogState();
}

class _JoinByInviteCodeDialogState extends State<_JoinByInviteCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _parseInviteInput(_controller.text);
    if (input == null) {
      setState(() => _errorMessage = '초대 코드 또는 링크를 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.tripService.getInviteInfo(
        code: input.code,
        token: input.token,
      );
      final joined = await widget.tripService.joinTrip(
        code: input.code,
        token: input.token,
        participantId: input.participantId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(joined.tripId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = '초대 코드 참여에 실패했습니다: $e';
      });
    }
  }

  _InviteJoinInput? _parseInviteInput(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme) {
      final code = uri.queryParameters['code']?.trim();
      final token = uri.queryParameters['token']?.trim();
      final participantIdValue = uri.queryParameters['participantId']?.trim();
      final participantId = participantIdValue == null
          ? null
          : int.tryParse(participantIdValue);
      if ((code == null || code.isEmpty) && (token == null || token.isEmpty)) {
        return null;
      }
      return _InviteJoinInput(
        code: code?.isEmpty == true ? null : code,
        token: token?.isEmpty == true ? null : token,
        participantId: participantId != null && participantId > 0
            ? participantId
            : null,
      );
    }

    return _InviteJoinInput(code: text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('초대 코드 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('inviteCodeOrLinkField'),
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: '초대 코드 또는 링크'),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? '참여 중...' : '참여'),
          ),
        ],
      ),
    );
  }
}

class _InviteJoinInput {
  final String? code;
  final String? token;
  final int? participantId;

  const _InviteJoinInput({this.code, this.token, this.participantId});
}

class _CurrentTripCover extends StatelessWidget {
  final TripSummary trip;
  final ValueChanged<TripSummary> onTap;

  const _CurrentTripCover({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${trip.title} 여행 열기',
      child: GestureDetector(
        onTap: () => onTap(trip),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 218,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandStrong],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _tripProgressLabel(trip),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                trip.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_dateRangeLabel(trip.startDate, trip.endDate)} · ${trip.defaultCurrency}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripStartBanner extends StatelessWidget {
  final VoidCallback onCreate;

  const _TripStartBanner({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.luggage_rounded,
            color: AppColors.brandStrong,
            size: 28,
          ),
          const SizedBox(height: 20),
          const Text('다음 여행을 준비해 볼까요?', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          const Text(
            '여행을 만들고 동행자를 초대해보세요.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onCreate,
            style: AppButtonStyles.elevatedPrimary(),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('여행 만들기'),
          ),
        ],
      ),
    );
  }
}

class _TripSectionTitle extends StatelessWidget {
  final String title;

  const _TripSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }
}

class _TripListRow extends StatelessWidget {
  final TripSummary trip;
  final ValueChanged<TripSummary> onTap;

  const _TripListRow({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${trip.title} 여행 열기',
      child: InkWell(
        onTap: () => onTap(trip),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: trip.tripStatus == 'ONGOING'
                      ? AppColors.brandSoft
                      : AppColors.neutralSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  trip.tripStatus == 'COMPLETED'
                      ? Icons.photo_album_outlined
                      : Icons.map_outlined,
                  color: trip.tripStatus == 'ONGOING'
                      ? AppColors.brandStrong
                      : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateRangeLabel(trip.startDate, trip.endDate)} · ${trip.defaultCurrency}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateRangeLabel(String? startDate, String? endDate) {
  if ((startDate == null || startDate.isEmpty) &&
      (endDate == null || endDate.isEmpty)) {
    return '날짜 미정';
  }
  return '${startDate ?? '시작 미정'} - ${endDate ?? '종료 미정'}';
}

String _tripProgressLabel(TripSummary trip) {
  final start = DateTime.tryParse(trip.startDate ?? '');
  final end = DateTime.tryParse(trip.endDate ?? '');
  final now = DateTime.now();
  if (start == null || end == null) return '여행 중';
  final day = now.difference(start).inDays + 1;
  final total = end.difference(start).inDays + 1;
  return '여행 중 · ${day.clamp(1, total)}일째';
}
