import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../main/screen/main_shell_screen.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/terms_agreement_service.dart';
import 'terms_agreement_screen.dart';

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
  late final PageController _pageController;
  bool _isLoading = false;
  int _pageIndex = 0;
  String? _errorMessage;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.edit_note_outlined,
      title: '함께 떠나는 여행을\n가볍게 기록하세요',
      description: '동행자와 일정, 지출, 기록을 한 곳에서 관리합니다.',
      visualTitle: '오사카 3박4일',
      rows: [('항공권', '320,000원'), ('숙소', '180,000원')],
      footerIcon: Icons.payments_outlined,
      footerLabel: '민서에게 보낼 돈',
      footerValue: '42,000원',
    ),
    _OnboardingPageData(
      icon: Icons.photo_camera_outlined,
      title: '순간은 피드처럼\n자연스럽게 남겨요',
      description: '사진, 장소, 메모를 여행 기록과 소비 내역으로 이어서 봅니다.',
      visualTitle: '오늘의 기록',
      rows: [('도톤보리 산책', '사진 4장'), ('라멘 저녁', '소비 연결')],
      footerIcon: Icons.chat_bubble_outline,
      footerLabel: '댓글과 반응',
      footerValue: '함께 보기',
    ),
    _OnboardingPageData(
      icon: Icons.currency_exchange_outlined,
      title: '환율과 정산까지\n끝까지 맞춰요',
      description: '여행 중 쓴 돈을 통화별로 기록하고 정산 흐름까지 확인합니다.',
      visualTitle: '정산 미리보기',
      rows: [('JPY 환율', '9.18 KRW'), ('총 지출', '582,000원')],
      footerIcon: Icons.check_circle_outline,
      footerLabel: '정산 준비',
      footerValue: '완료',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MainShellScreen(
              authService: widget.authService,
              tripService: widget.tripService,
              termsAgreementService: widget.termsAgreementService,
            ),
          ),
        );
        return;
      }

      if (result.isProfileRequired) {
        _openTermsAgreement(result);
        return;
      }

      if (result.isPhoneVerificationRequired && result.temporaryToken != null) {
        _openTermsAgreement(result);
        return;
      }

      setState(() => _errorMessage = '로그인 응답 상태를 확인할 수 없습니다.');
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) {
        setState(() => _errorMessage = '로그인이 취소되었습니다.');
      } else {
        setState(() => _errorMessage = '카카오 로그인 실패: ${e.message}');
      }
    } on KakaoClientException catch (e) {
      setState(() => _errorMessage = '카카오 SDK 오류: ${e.message}');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openTermsAgreement(AuthLoginResult result) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TermsAgreementScreen(
          authService: widget.authService,
          tripService: widget.tripService,
          termsAgreementService:
              widget.termsAgreementService ?? TermsAgreementService(),
          loginResult: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(),
              const Spacer(),
              SizedBox(
                height: 338,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) {
                    return _OnboardingPage(data: _pages[index]);
                  },
                ),
              ),
              const Spacer(),
              _PageDots(count: _pages.length, activeIndex: _pageIndex),
              const SizedBox(height: 18),
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
    return Column(
      children: [
        _OnboardingVisual(data: data),
        const SizedBox(height: 24),
        _OnboardingCopy(data: data),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: AppColors.ink)),
            ),
            child: Center(
              child: Text('T', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        SizedBox(width: 10),
        Text(
          'TogetherTrip',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingVisual({required this.data});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: SizedBox(
          height: 204,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border.all(color: AppColors.ink),
              borderRadius: AppRadii.controlRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 12),
                  for (final row in data.rows) ...[
                    _VisualRow(label: row.$1, value: row.$2),
                    const SizedBox(height: 8),
                  ],
                  const Spacer(),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(data.footerIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.footerLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            data.footerValue,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
          border: Border.all(color: AppColors.line),
          borderRadius: AppRadii.controlRadius,
        ),
        child: Icon(icon, size: 17, color: AppColors.ink),
      ),
    );
  }
}

class _VisualRow extends StatelessWidget {
  final String label;
  final String value;

  const _VisualRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.lineSoft),
        borderRadius: AppRadii.controlRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  const _OnboardingCopy({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
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

class _PageDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _PageDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _Dot(isActive: index == activeIndex),
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isActive;

  const _Dot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isActive ? 18 : 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink : const Color(0xFFC7C7C7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
