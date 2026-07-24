import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../main/screen/main_shell_screen.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/terms_agreement_service.dart';
import 'sign_up_profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final AuthService authService;
  final TripService? tripService;
  final TermsAgreementService? termsAgreementService;

  const OnboardingScreen({
    super.key,
    required this.authService,
    this.tripService,
    this.termsAgreementService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  static const _page = _OnboardingPageData(
    icon: Icons.receipt_long_outlined,
    title: '한눈에 보는 정산',
    description: '보낼 돈과 받을 돈을 간단하게',
    visualTitle: '오사카 3박 4일',
    rows: [('받을 돈', '42,000원'), ('보낼 돈', '18,000원')],
    footerIcon: Icons.check_circle_outline,
    footerLabel: '함께 기록한 여행',
    footerValue: '정산 준비 완료',
  );

  Future<void> _startWithKakao() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.loginWithKakao();
      if (!mounted) return;

      if (result.isAuthenticated) {
        await _openMainOrRepairSignup();
        return;
      }

      if (result.isProfileRequired) {
        _openSignUpProfile(result);
        return;
      }

      setState(() => _errorMessage = '로그인 응답 상태를 확인할 수 없습니다.');
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) {
        _clearLoginError();
      } else {
        setState(() => _errorMessage = '카카오 로그인 실패: ${e.message}');
      }
    } on KakaoClientException catch (e) {
      if (_isKakaoLoginCancelled(e)) {
        _clearLoginError();
      } else {
        setState(() => _errorMessage = '카카오 SDK 오류: ${e.message}');
      }
    } on PlatformException catch (e) {
      if (_isKakaoLoginCancelled(e)) {
        _clearLoginError();
      } else {
        setState(() => _errorMessage = '카카오 SDK 오류: ${e.message ?? e.code}');
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (_isKakaoLoginCancelled(e)) {
        _clearLoginError();
      } else {
        setState(() => _errorMessage = '오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearLoginError() {
    if (!mounted) return;
    setState(() => _errorMessage = null);
  }

  bool _isKakaoLoginCancelled(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('cancel') ||
        text.contains('canceled') ||
        text.contains('cancelled') ||
        text.contains('accessdenied') ||
        text.contains('access_denied');
  }

  Future<void> _openMainOrRepairSignup() async {
    final termsAgreementService =
        widget.termsAgreementService ??
        TermsAgreementService(authService: widget.authService);
    final profile = await widget.authService.getMe();
    final terms = await termsAgreementService.getTerms();
    final agreedCodes = await termsAgreementService.getAgreedTermCodes();
    final requiredTerms = terms.where((term) => term.required).toList();
    final hasAgreedAllRequired =
        requiredTerms.isNotEmpty &&
        requiredTerms.every((term) => agreedCodes.contains(term.code));
    final hasCompletedProfile = profile.nickname.trim().isNotEmpty;

    if (!mounted) return;

    if (!hasCompletedProfile || !hasAgreedAllRequired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SignUpProfileScreen(
            authService: widget.authService,
            tripService: widget.tripService,
            termsAgreementService: termsAgreementService,
            prefillProfile: profile,
            restoreExistingTerms: true,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShellScreen(
          authService: widget.authService,
          tripService: widget.tripService,
          termsAgreementService: termsAgreementService,
        ),
      ),
    );
  }

  void _openSignUpProfile(AuthLoginResult result) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignUpProfileScreen(
          authService: widget.authService,
          tripService: widget.tripService,
          termsAgreementService: widget.termsAgreementService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(),
              const Spacer(flex: 2),
              const SizedBox(height: 360, child: _OnboardingPage(data: _page)),
              const Spacer(flex: 2),
              if (_errorMessage != null) ...[
                AppErrorText(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startWithKakao,
                  style: AppButtonStyles.kakao(),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          '카카오로 시작하기',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final String visualTitle;
  final List<(String, String)> rows;
  final IconData footerIcon;
  final String footerLabel;
  final String footerValue;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.visualTitle,
    required this.rows,
    required this.footerIcon,
    required this.footerLabel,
    required this.footerValue,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 360;
        return Column(
          children: [
            _OnboardingVisual(data: data, compact: compact),
            SizedBox(height: compact ? 14 : 24),
            _OnboardingCopy(data: data, compact: compact),
          ],
        );
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/brand/togethertrip-lockup.png',
        width: 176,
        height: 42,
        alignment: Alignment.centerLeft,
        fit: BoxFit.contain,
        semanticLabel: 'TogetherTrip',
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final _OnboardingPageData data;
  final bool compact;

  const _OnboardingVisual({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: SizedBox(
          height: compact ? 198 : 216,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _VisualIcon(icon: data.icon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.visualTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const Text(
                        'D-12',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  for (final row in data.rows) ...[
                    _VisualRow(label: row.$1, value: row.$2, compact: compact),
                    SizedBox(height: compact ? 6 : 8),
                  ],
                  const Spacer(),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: compact ? 8 : 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            data.footerIcon,
                            size: 16,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.footerLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSubtle,
                              ),
                            ),
                          ),
                          Text(
                            data.footerValue,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisualIcon extends StatelessWidget {
  final IconData icon;

  const _VisualIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 17, color: AppColors.brand),
      ),
    );
  }
}

class _VisualRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _VisualRow({
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 8 : 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSubtle,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCopy extends StatelessWidget {
  final _OnboardingPageData data;
  final bool compact;

  const _OnboardingCopy({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: TextStyle(
            fontSize: compact ? 22 : 24,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          data.description,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSubtle,
          ),
        ),
      ],
    );
  }
}
