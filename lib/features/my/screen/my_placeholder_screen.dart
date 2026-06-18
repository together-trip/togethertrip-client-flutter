import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../auth/screen/onboarding_screen.dart';
import '../../auth/screen/sign_up_profile_screen.dart';
import '../../auth/screen/terms_list_screen.dart';
import '../../auth/service/auth_service.dart';
import '../../auth/service/terms_agreement_service.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../widget/my_menu_row.dart';
import '../widget/my_profile_header.dart';

class MyPlaceholderScreen extends StatefulWidget {
  final AuthService? authService;
  final TermsAgreementService? termsAgreementService;
  final VoidCallback? onBack;

  const MyPlaceholderScreen({
    super.key,
    this.authService,
    this.termsAgreementService,
    this.onBack,
  });

  @override
  State<MyPlaceholderScreen> createState() => _MyPlaceholderScreenState();
}

class _MyPlaceholderScreenState extends State<MyPlaceholderScreen> {
  late final AuthService _authService;
  late final TermsAgreementService _termsAgreementService;

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isWithdrawing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _termsAgreementService =
        widget.termsAgreementService ??
        TermsAgreementService(authService: _authService);
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
          termsAgreementService: _termsAgreementService,
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
              style: AppButtonStyles.dangerText(),
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
          builder: (_) => OnboardingScreen(
            authService: _authService,
            termsAgreementService: _termsAgreementService,
          ),
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

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TermsListScreen(termsAgreementService: _termsAgreementService),
      ),
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
          builder: (_) => OnboardingScreen(
            authService: _authService,
            termsAgreementService: _termsAgreementService,
          ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 24),
          color: AppColors.ink,
          tooltip: '뒤로',
        ),
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none, size: 22),
            color: AppColors.ink,
            tooltip: '알림',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          MyProfileHeader(
            profile: _profile,
            isLoading: _isLoading,
            onTap: _openProfileEdit,
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: AppErrorText(_errorMessage!)),
                  TextButton(
                    onPressed: _isLoading ? null : _loadProfile,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          // 메뉴 목록
          MyMenuRow(
            icon: Icons.manage_accounts_outlined,
            label: '개인정보 수정',
            onTap: _isLoading || _profile == null ? null : _openProfileEdit,
          ),
          MyMenuRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: () => _showPreparingMessage('알림 설정'),
          ),
          MyMenuRow(
            icon: Icons.article_outlined,
            label: '약관',
            onTap: _openTerms,
          ),
          MyMenuRow(icon: Icons.logout, label: '로그아웃', onTap: _confirmLogout),
          MyMenuRow(
            icon: Icons.person_remove_outlined,
            label: _isWithdrawing ? '탈퇴 처리 중…' : '회원 탈퇴',
            labelColor: AppColors.danger,
            onTap: _isWithdrawing ? null : _confirmWithdraw,
          ),
        ],
      ),
    );
  }
}
