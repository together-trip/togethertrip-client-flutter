import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/network/api_client.dart';
import '../../main/screen/main_placeholder_screen.dart';
import '../service/auth_service.dart';
import 'sign_up_profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final AuthService authService;

  const OnboardingScreen({super.key, required this.authService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;
  String? _errorMessage;

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
            builder: (_) => const MainPlaceholderScreen(),
          ),
        );
        return;
      }

      if (result.isProfileRequired) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignUpProfileScreen(
              authService: widget.authService,
              temporaryToken: null,
            ),
          ),
        );
        return;
      }

      if (result.isPhoneVerificationRequired && result.temporaryToken != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignUpProfileScreen(
              authService: widget.authService,
              temporaryToken: result.temporaryToken!,
            ),
          ),
        );
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
              const _OnboardingVisual(),
              const SizedBox(height: 28),
              const _OnboardingCopy(),
              const Spacer(),
              const _PageDots(),
              const SizedBox(height: 18),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startWithKakao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF1A1A1A)),
                    ),
                  ),
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
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF1A1A1A)),
              ),
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
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _PlaceholderPainter()),
                ),
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        '여행 이미지',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCopy extends StatelessWidget {
  const _OnboardingCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '함께 떠나는 여행을\n가볍게 기록하세요',
          style: TextStyle(
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 12),
        Text(
          '동행자와 일정, 지출, 기록을 한 곳에서 관리합니다.',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B6B6B)),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Dot(isActive: true),
        SizedBox(width: 6),
        _Dot(isActive: false),
        SizedBox(width: 6),
        _Dot(isActive: false),
      ],
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
          color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFFC7C7C7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E5E5)
      ..strokeWidth = 1;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
