import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../auth/screen/onboarding_screen.dart';
import '../../auth/screen/sign_up_profile_screen.dart';
import '../../auth/screen/terms_list_screen.dart';
import '../../auth/service/auth_service.dart';
import '../../auth/service/terms_agreement_service.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../../notification/service/notification_service.dart';
import '../../notification/widget/notification_badge_button.dart';
import '../../moderation/screen/blocked_users_screen.dart';
import '../../moderation/service/moderation_service.dart';
import '../../trip/service/trip_service.dart';
import '../widget/my_menu_row.dart';
import '../widget/my_profile_header.dart';
import '../service/public_site_link_service.dart';

class MyPlaceholderScreen extends StatefulWidget {
  final AuthService? authService;
  final TermsAgreementService? termsAgreementService;
  final VoidCallback? onBack;
  final ModerationService? moderationService;
  final VoidCallback? onModerationChanged;
  final PublicSiteLinks? publicSiteLinks;
  final ExternalLinkLauncher? externalLinkLauncher;

  const MyPlaceholderScreen({
    super.key,
    this.authService,
    this.termsAgreementService,
    this.onBack,
    this.moderationService,
    this.onModerationChanged,
    this.publicSiteLinks,
    this.externalLinkLauncher,
  });

  @override
  State<MyPlaceholderScreen> createState() => _MyPlaceholderScreenState();
}

class _MyPlaceholderScreenState extends State<MyPlaceholderScreen> {
  late final AuthService _authService;
  late final TermsAgreementService _termsAgreementService;
  late final ModerationService _moderationService;
  late final PublicSiteLinks _publicSiteLinks;
  late final ExternalLinkLauncher _externalLinkLauncher;

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
    _moderationService =
        widget.moderationService ??
        ModerationService(authService: _authService);
    _publicSiteLinks = widget.publicSiteLinks ?? PublicSiteLinks();
    _externalLinkLauncher =
        widget.externalLinkLauncher ?? UrlLauncherExternalLinkLauncher();
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('탈퇴하면 프로필, OAuth 연결, 약관 동의, 알림과 푸시 토큰이 삭제됩니다.'),
                const SizedBox(height: 10),
                const Text(
                  '정산과 지출 원장은 참여자 간 금액 기록을 보호하기 위해 개인정보를 익명화한 상태로 보관됩니다.',
                ),
                const SizedBox(height: 10),
                const Text('같은 소셜 계정으로 다시 가입해도 새로운 계정으로 처리됩니다.'),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('accountDeletionPolicyLink'),
                  onPressed: () => _openPublicSite(
                    PublicSitePage.accountDeletion,
                    '계정 삭제 안내',
                  ),
                  child: const Text('계정 삭제 및 데이터 처리 안내 보기'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              key: const ValueKey('confirmWithdrawButton'),
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

  Future<void> _openNotifications() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationListScreen(
          notificationService: NotificationService(authService: _authService),
          tripService: TripService(authService: _authService),
        ),
      ),
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

  Future<void> _openBlockedUsers() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            BlockedUsersScreen(moderationService: _moderationService),
      ),
    );
    if (changed == true) widget.onModerationChanged?.call();
  }

  Future<void> _openPublicSite(PublicSitePage page, String label) async {
    try {
      final opened = await _externalLinkLauncher.open(
        _publicSiteLinks.get(page),
      );
      if (!opened) throw StateError('url launch failed');
    } catch (_) {
      if (!mounted) return;
      final message = '$label 링크를 열지 못했습니다.';
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 24),
          color: AppColors.ink,
          tooltip: '뒤로',
        ),
        title: const Text(
          '마이',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          NotificationBadgeButton(
            onPressed: _openNotifications,
            notificationService: NotificationService(authService: _authService),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text('설정', style: AppTextStyles.caption),
          ),
          MyMenuRow(
            icon: Icons.description_outlined,
            label: '약관 및 동의 관리',
            onTap: _openTerms,
          ),
          MyMenuRow(
            key: const ValueKey('termsOfServiceLink'),
            icon: Icons.open_in_new,
            label: '이용약관',
            onTap: () => _openPublicSite(PublicSitePage.termsOfService, '이용약관'),
          ),
          MyMenuRow(
            key: const ValueKey('privacyPolicyLink'),
            icon: Icons.privacy_tip_outlined,
            label: '개인정보처리방침',
            onTap: () =>
                _openPublicSite(PublicSitePage.privacyPolicy, '개인정보처리방침'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
            child: Text('안전 및 지원', style: AppTextStyles.caption),
          ),
          MyMenuRow(
            icon: Icons.block_outlined,
            label: '차단한 사용자',
            onTap: _openBlockedUsers,
          ),
          MyMenuRow(
            key: const ValueKey('customerSupportLink'),
            icon: Icons.support_agent_outlined,
            label: '고객지원',
            onTap: () =>
                _openPublicSite(PublicSitePage.customerSupport, '고객지원'),
          ),
          MyMenuRow(
            key: const ValueKey('communityPolicyLink'),
            icon: Icons.shield_outlined,
            label: '커뮤니티 운영정책',
            onTap: () =>
                _openPublicSite(PublicSitePage.communityPolicy, '커뮤니티 운영정책'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
            child: Text('계정', style: AppTextStyles.caption),
          ),
          MyMenuRow(
            key: const ValueKey('accountDeletionLink'),
            icon: Icons.person_remove_outlined,
            label: '계정 삭제 안내',
            onTap: () => _openPublicSite(
              PublicSitePage.accountDeletion,
              '계정 삭제 안내',
            ),
          ),
          MyMenuRow(icon: Icons.logout, label: '로그아웃', onTap: _confirmLogout),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('withdrawButton'),
                onPressed: _isWithdrawing ? null : _confirmWithdraw,
                style: AppButtonStyles.dangerText(),
                child: Text(_isWithdrawing ? '탈퇴 처리 중…' : '회원 탈퇴'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
