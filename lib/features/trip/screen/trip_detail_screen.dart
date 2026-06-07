import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../service/trip_service.dart';
import 'trip_form_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  final TripService? tripService;

  const TripDetailScreen({super.key, required this.tripId, this.tripService});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripService _tripService;

  TripDetail? _trip;
  int? _currentUserId;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trip = await _tripService.getTrip(widget.tripId);
      final currentUser = await _tripService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _currentUserId = currentUser.id;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 상세를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEdit() async {
    final trip = _trip;
    if (trip == null) return;

    final updated = await Navigator.of(context).push<TripDetail>(
      MaterialPageRoute<TripDetail>(
        builder: (_) =>
            TripFormScreen(tripService: _tripService, initialTrip: trip),
      ),
    );

    if (updated != null) {
      _changed = true;
      await _loadTrip();
    }
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('여행 삭제'),
          content: const Text('이 여행을 삭제하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCC0000),
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteTrip();
    }
  }

  Future<void> _deleteTrip() async {
    setState(() => _isDeleting = true);
    try {
      await _tripService.deleteTrip(widget.tripId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 삭제에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageTrip =
        _trip != null &&
        _currentUserId != null &&
        _trip!.ownerUserId == _currentUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(_trip?.title ?? '여행 상세'),
          actions: canManageTrip
              ? [
                  TextButton(onPressed: _openEdit, child: const Text('수정')),
                  TextButton(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCC0000),
                    ),
                    child: Text(_isDeleting ? '삭제 중' : '삭제'),
                  ),
                ]
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final trip = _trip;
    if (trip == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        children: [
          const Text(
            '여행 상세를 불러오지 못했습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton(onPressed: _loadTrip, child: const Text('다시 시도')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrip,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            trip.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${_dateRangeLabel(trip.startDate, trip.endDate)} · ${trip.defaultCurrency}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          _Section(
            title: '상태',
            children: [
              _InfoRow(label: '여행', value: _tripStatusLabel(trip.tripStatus)),
              _InfoRow(
                label: '정산',
                value: _settlementStatusLabel(trip.settlementStatus),
              ),
            ],
          ),
          _Section(
            title: '국가',
            children: trip.countries.isEmpty
                ? const [_EmptyLine(text: '등록된 국가가 없습니다.')]
                : trip.countries
                      .map(
                        (country) => _InfoRow(
                          label: country.countryCode,
                          value: country.countryName,
                        ),
                      )
                      .toList(),
          ),
          _Section(
            title: '참여자',
            children: trip.participants.isEmpty
                ? const [_EmptyLine(text: '등록된 참여자가 없습니다.')]
                : trip.participants
                      .map(
                        (participant) => _InfoRow(
                          label: _roleLabel(participant.participantRole),
                          value: participant.displayName,
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
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

String _roleLabel(String role) {
  return role == 'LEADER' ? '방장' : '동행자';
}
