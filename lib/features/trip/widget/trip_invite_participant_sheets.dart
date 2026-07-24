import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(value, style: AppTextStyles.body),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(copiedMessage)));
                },
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('복사'),
                style: AppButtonStyles.elevatedPrimary(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TripParticipantManagerSheet extends StatefulWidget {
  final TripDetail trip;
  final TripService tripService;
  final bool initiallyShowAddPanel;

  const TripParticipantManagerSheet({
    super.key,
    required this.trip,
    required this.tripService,
    this.initiallyShowAddPanel = false,
  });

  @override
  State<TripParticipantManagerSheet> createState() =>
      _TripParticipantManagerSheetState();
}

class _ParticipantRoleBadge extends StatelessWidget {
  final String label;

  const _ParticipantRoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.brandStrong,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TripParticipantManagerSheetState
    extends State<TripParticipantManagerSheet> {
  late List<TripParticipant> _participants;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  int? _selectedGuestParticipantId;
  UserSearchUser? _searchedUser;
  bool _isBusy = false;
  late bool _showAddPanel;
  String? _message;
  TripParticipant? _recentlyAddedGuest;

  @override
  void initState() {
    super.initState();
    _participants = [...widget.trip.participants];
    _showAddPanel = widget.initiallyShowAddPanel;
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

  Future<void> _createGuestInviteLink(TripParticipant participant) {
    return _run(() async {
      final invite = await widget.tripService.createInviteLink(
        widget.trip.id,
        participantId: participant.id,
      );
      if (!mounted) return;
      await showAppBottomSheet<void>(
        context: context,
        builder: (context) {
          return TripInviteValueSheet(
            title: '${participant.displayName} 초대 링크',
            value: invite.inviteUrl,
            copiedMessage: '비회원 동행 초대 링크를 복사했습니다.',
          );
        },
      );
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
          child: ColoredBox(
            color: AppColors.background,
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
                const Text('참여자 관리', style: AppTextStyles.screenTitle),
                const SizedBox(height: 6),
                Text(
                  '함께하는 사람을 확인하고 필요한 초대를 보내세요.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.trip.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sectionTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '함께하는 사람 ${_participants.length}명',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_participants.length}/10명',
                          style: const TextStyle(
                            color: AppColors.brandStrong,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '동행자',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('방장만 관리 가능', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                ..._participants.map((participant) {
                  final isLeader = participant.participantRole == 'LEADER';
                  final isGuest = participant.userId == null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: isLeader
                          ? AppColors.brandSoft
                          : AppColors.neutralSoft,
                      child: Icon(
                        isLeader ? Icons.star_rounded : Icons.person_outline,
                        color: isLeader
                            ? AppColors.brandStrong
                            : AppColors.textMuted,
                      ),
                    ),
                    title: Text(
                      participant.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      isLeader
                          ? '방장'
                          : participant.userId == null
                          ? '비회원 동행'
                          : '사용자',
                    ),
                    trailing: isLeader
                        ? const _ParticipantRoleBadge(label: '나')
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGuest)
                                TextButton.icon(
                                  key: ValueKey(
                                    'guestInviteLinkButton-${participant.id}',
                                  ),
                                  onPressed: _isBusy
                                      ? null
                                      : () =>
                                            _createGuestInviteLink(participant),
                                  icon: const Icon(
                                    Icons.link_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('초대'),
                                ),
                              PopupMenuButton<String>(
                                tooltip: '${participant.displayName} 관리',
                                icon: const Icon(Icons.more_horiz_rounded),
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    _removeParticipant(participant);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text(
                                      '동행자 제거',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: AppColors.lineSoft),
                ),
                const Text(
                  '비회원 동행의 소비 기록은 실제 사용자와 연결해도 그대로 유지돼요.',
                  style: AppTextStyles.caption,
                ),
                if (_showAddPanel) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 1, color: AppColors.lineSoft),
                  ),
                  const Text(
                    '새 동행 추가',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '아직 가입하지 않은 사람도 이름만으로 먼저 추가할 수 있어요.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('guestParticipantNameField'),
                    controller: _nameController,
                    decoration: AppInputDecorations.filled(hintText: '이름'),
                    onSubmitted: (_) => _addGuest(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('addGuestParticipantButton'),
                    onPressed: _isBusy ? null : _addGuest,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('이름으로 추가'),
                    style: AppButtonStyles.outlined(sideColor: AppColors.brand),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSubtle,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 1, color: AppColors.lineSoft),
                  ),
                  const Text(
                    '비회원을 실제 사용자와 연결',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedGuestParticipantId,
                    decoration: AppInputDecorations.filled(
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
                        : (value) => setState(
                            () => _selectedGuestParticipantId = value,
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('participantManagerNicknameField'),
                    controller: _nicknameController,
                    decoration: AppInputDecorations.filled(hintText: '닉네임 검색'),
                    onSubmitted: (_) => _searchUser(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('participantManagerSearchUserButton'),
                    onPressed: _isBusy ? null : _searchUser,
                    icon: const Icon(Icons.search_rounded, size: 18),
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
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  key: const ValueKey('toggleParticipantAddPanelButton'),
                  onPressed: _isBusy
                      ? null
                      : () {
                          if (_showAddPanel) {
                            setState(() => _showAddPanel = false);
                          } else {
                            setState(() => _showAddPanel = true);
                          }
                        },
                  style: AppButtonStyles.elevatedPrimary(),
                  child: Text(_showAddPanel ? '동행자 목록으로' : '+ 동행자 추가'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('완료'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
