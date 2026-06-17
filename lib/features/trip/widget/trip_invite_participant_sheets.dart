import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../service/trip_service.dart';

class TripInviteValueSheet extends StatelessWidget {
  final String title;
  final String value;
  final String copiedMessage;

  const TripInviteValueSheet({
    super.key,
    required this.title,
    required this.value,
    required this.copiedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SelectableText(value, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(copiedMessage)));
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('복사'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripParticipantManagerSheet extends StatefulWidget {
  final TripDetail trip;
  final TripService tripService;

  const TripParticipantManagerSheet({
    super.key,
    required this.trip,
    required this.tripService,
  });

  @override
  State<TripParticipantManagerSheet> createState() =>
      _TripParticipantManagerSheetState();
}

class _TripParticipantManagerSheetState
    extends State<TripParticipantManagerSheet> {
  late List<TripParticipant> _participants;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  int? _selectedGuestParticipantId;
  UserSearchUser? _searchedUser;
  bool _isBusy = false;
  String? _message;
  TripParticipant? _recentlyAddedGuest;

  @override
  void initState() {
    super.initState();
    _participants = [...widget.trip.participants];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _addGuest() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _message = '비회원 동행 이름을 입력해 주세요.');
      return Future.value();
    }
    return _run(() async {
      final participant = await widget.tripService.addTemporaryParticipant(
        widget.trip.id,
        TripCompanionInput(displayName: name, profileImageUrl: null),
      );
      setState(() {
        _participants.add(participant);
        _recentlyAddedGuest = participant;
        _nameController.clear();
        _message = '비회원 동행을 추가했습니다.';
      });
    });
  }

  Future<void> _searchUser() {
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 2 || nickname.length > 20) {
      setState(() => _message = '닉네임은 2~20자로 검색해 주세요.');
      return Future.value();
    }
    return _run(() async {
      final result = await widget.tripService.searchUserByNickname(nickname);
      setState(() {
        final user = result.user;
        if (user != null && user.userId == widget.trip.ownerUserId) {
          _searchedUser = null;
          _message = '본인은 동행자로 추가할 수 없습니다.';
          return;
        }
        _searchedUser = user;
        _message = result.found ? null : '일치하는 사용자를 찾지 못했습니다.';
      });
    });
  }

  Future<void> _linkSelectedGuest() {
    final participantId = _selectedGuestParticipantId;
    final user = _searchedUser;
    if (participantId == null || user == null) {
      setState(() => _message = '연결할 비회원 동행과 사용자를 선택해 주세요.');
      return Future.value();
    }
    return _run(() async {
      final linked = await widget.tripService.linkParticipant(
        widget.trip.id,
        participantId: participantId,
        userId: user.userId,
      );
      setState(() {
        final index = _participants.indexWhere(
          (participant) => participant.id == participantId,
        );
        if (index >= 0) _participants[index] = linked;
        _selectedGuestParticipantId = null;
        _searchedUser = null;
        _nicknameController.clear();
        _message = '비회원 동행을 실제 사용자와 연결했습니다.';
      });
    });
  }

  Future<void> _removeParticipant(TripParticipant participant) {
    return _run(() async {
      await widget.tripService.removeParticipant(
        widget.trip.id,
        participant.id,
      );
      setState(() {
        _participants.removeWhere((item) => item.id == participant.id);
        if (_recentlyAddedGuest?.id == participant.id) {
          _recentlyAddedGuest = null;
        }
        _message = '참여자를 제거했습니다.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final guestParticipants = _participants
        .where((participant) => participant.userId == null)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '참여자 관리',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ..._participants.map((participant) {
                final isLeader = participant.participantRole == 'LEADER';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(participant.displayName),
                  subtitle: Text(
                    isLeader
                        ? '방장'
                        : participant.userId == null
                        ? '비회원 동행'
                        : '사용자',
                  ),
                  trailing: isLeader
                      ? null
                      : IconButton(
                          onPressed: _isBusy
                              ? null
                              : () => _removeParticipant(participant),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: const Color(0xFFCC0000),
                          tooltip: '제거',
                        ),
                );
              }),
              const Divider(height: 28),
              const Text(
                '비회원 동행 추가',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('guestParticipantNameField'),
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '이름',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addGuest(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('addGuestParticipantButton'),
                onPressed: _isBusy ? null : _addGuest,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('비회원 동행 추가'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
              if (_recentlyAddedGuest != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  key: const ValueKey('recentlyAddedGuestParticipant'),
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF2F2F2),
                    child: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  title: Text(_recentlyAddedGuest!.displayName),
                  subtitle: const Text('방금 추가한 비회원 동행'),
                ),
              ],
              const Divider(height: 28),
              const Text(
                '비회원을 실제 사용자와 연결',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedGuestParticipantId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '비회원 동행 선택',
                ),
                items: guestParticipants
                    .map(
                      (participant) => DropdownMenuItem<int>(
                        value: participant.id,
                        child: Text(participant.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _isBusy
                    ? null
                    : (value) =>
                          setState(() => _selectedGuestParticipantId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('participantManagerNicknameField'),
                controller: _nicknameController,
                decoration: const InputDecoration(
                  hintText: '닉네임 검색',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _searchUser(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('participantManagerSearchUserButton'),
                onPressed: _isBusy ? null : _searchUser,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('사용자 검색'),
              ),
              if (_searchedUser != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_searchedUser!.nickname),
                  subtitle: const Text('검색된 사용자'),
                  trailing: ElevatedButton(
                    onPressed: _isBusy ? null : _linkSelectedGuest,
                    child: const Text('연결'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('완료'),
              ),
            ],
          ),
        );
      },
    );
  }
}
