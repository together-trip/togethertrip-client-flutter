import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/screen/onboarding_screen.dart';
import '../../auth/screen/sign_up_profile_screen.dart';
import '../../auth/service/auth_service.dart';
import '../../notification/screen/notification_list_screen.dart';

class MyPlaceholderScreen extends StatefulWidget {
  final AuthService? authService;
  final VoidCallback? onBack;

  const MyPlaceholderScreen({super.key, this.authService, this.onBack});

  @override
  State<MyPlaceholderScreen> createState() => _MyPlaceholderScreenState();
}

class _MyPlaceholderScreenState extends State<MyPlaceholderScreen> {
  late final AuthService _authService;

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isWithdrawing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.getMe();
      if (!mounted) return;
      setState(() => _profile = profile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '내 정보를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openProfileEdit() async {
    final profile = _profile;
    if (profile == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SignUpProfileScreen(
          authService: _authService,
          temporaryToken: null,
          initialProfile: profile,
        ),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _confirmWithdraw() async {
    if (_isWithdrawing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const Text('정말 탈퇴하시겠어요?'),
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
              child: const Text('탈퇴'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _withdraw();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('현재 계정에서 로그아웃하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _logout();
  }

  Future<void> _logout() async {
    setState(() => _errorMessage = null);

    try {
      await _authService.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingScreen(authService: _authService),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '로그아웃에 실패했습니다: $e');
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationListScreen()),
    );
  }

  void _showPreparingMessage(String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$featureName 기능은 아직 준비 중입니다.')));
  }

  Future<void> _withdraw() async {
    setState(() {
      _isWithdrawing = true;
      _errorMessage = null;
    });

    try {
      await _authService.deleteAccount();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingScreen(authService: _authService),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '회원 탈퇴에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _profile?.nickname;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 24),
          color: const Color(0xFF1A1A1A),
          tooltip: '뒤로',
        ),
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none, size: 22),
            color: const Color(0xFF1A1A1A),
            tooltip: '알림',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 프로필 헤더
          GestureDetector(
            onTap: _isLoading || _profile == null ? null : _openProfileEdit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF2F2F2),
                      border: Border.all(color: const Color(0xFFC7C7C7)),
                    ),
                    child: Center(
                      child: Text(
                        (nickname != null && nickname.isNotEmpty)
                            ? nickname.substring(0, 1)
                            : '나',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading ? '불러오는 중…' : (nickname ?? '닉네임 없음'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '프로필 보기',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: Color(0xFF9E9E9E),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _loadProfile,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          // 메뉴 목록
          _MenuRow(
            icon: Icons.manage_accounts_outlined,
            label: '개인정보 수정',
            onTap: _isLoading || _profile == null ? null : _openProfileEdit,
          ),
          _MenuRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: () => _showPreparingMessage('알림 설정'),
          ),
          _MenuRow(
            icon: Icons.article_outlined,
            label: '약관',
            onTap: () => _showPreparingMessage('약관'),
          ),
          _MenuRow(icon: Icons.logout, label: '로그아웃', onTap: _confirmLogout),
          _MenuRow(
            icon: Icons.person_remove_outlined,
            label: _isWithdrawing ? '탈퇴 처리 중…' : '회원 탈퇴',
            labelColor: const Color(0xFFCC0000),
            onTap: _isWithdrawing ? null : _confirmWithdraw,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor = const Color(0xFF1A1A1A),
  });

  final IconData icon;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: labelColor),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF9E9E9E)),
          ],
        ),
      ),
    );
  }
}
