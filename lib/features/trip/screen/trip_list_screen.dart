import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../../../core/network/api_client.dart';
import '../../notification/screen/notification_list_screen.dart';
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
  _TripHomeFilter _selectedFilter = _TripHomeFilter.all;
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
      final page = await _tripService.getTrips(status: _selectedFilter.status);
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
      final page = await _tripService.getTrips(
        status: _selectedFilter.status,
        cursor: _nextCursor,
      );
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

  void _openNotifications() {
    Navigator.of(context).push(
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
      ownerUserId: 0,
    );
  }

  Future<void> _selectFilter(_TripHomeFilter filter) async {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    await _loadTrips();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
          IconButton(
            key: const ValueKey('notificationButton'),
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none, size: 22),
            color: AppColors.ink,
            tooltip: '알림',
          ),
          IconButton(
            key: const ValueKey('joinTripByInviteCodeButton'),
            onPressed: _openJoinByInviteCode,
            icon: const Icon(Icons.pin_outlined, size: 22),
            color: AppColors.ink,
            tooltip: '초대 코드 입력',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _TripHomeTabs(
            selectedFilter: _selectedFilter,
            onSelect: _selectFilter,
          ),
        ),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      itemCount: _trips.length + 1,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _trips.length) {
          if (!_hasNext) return const SizedBox(height: 4);
          return OutlinedButton(
            onPressed: _isLoadingMore ? null : _loadMore,
            child: Text(_isLoadingMore ? '불러오는 중...' : '더 보기'),
          );
        }

        return _TripCard(trip: _trips[index], onTap: _openDetail);
      },
    );
  }
}

enum _TripHomeFilter {
  all(label: '전체', status: null),
  ongoing(label: '진행 중', status: 'ONGOING'),
  planned(label: '계획 중', status: 'PLANNED'),
  completed(label: '지난 여행', status: 'COMPLETED');

  final String label;
  final String? status;

  const _TripHomeFilter({required this.label, required this.status});
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

class _TripHomeTabs extends StatelessWidget {
  final _TripHomeFilter selectedFilter;
  final ValueChanged<_TripHomeFilter> onSelect;

  const _TripHomeTabs({required this.selectedFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      child: Row(
        children: _TripHomeFilter.values.map((filter) {
          final isActive = filter == selectedFilter;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(filter),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: isActive
                              ? AppColors.ink
                              : AppColors.textSubtle,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    width: isActive ? 52 : 0,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripSummary trip;
  final ValueChanged<TripSummary> onTap;

  const _TripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(trip),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: const Color(0xFFE2E2E2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(label: _tripStatusLabel(trip.tripStatus)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _dateRangeLabel(trip.startDate, trip.endDate),
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A)),
            ),
            const SizedBox(height: 8),
            Text(
              '${trip.defaultCurrency} · 정산 ${_settlementStatusLabel(trip.settlementStatus)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

String _tripStatusLabel(String status) {
  return switch (status) {
    'ONGOING' => '진행중',
    'COMPLETED' => '완료',
    _ => '예정',
  };
}

String _settlementStatusLabel(String status) {
  return switch (status) {
    'IN_PROGRESS' => '진행중',
    'SETTLED' => '완료',
    _ => '미시작',
  };
}
