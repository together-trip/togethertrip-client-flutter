import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/widget/app_design.dart';
import '../service/auth_service.dart';

class KakaoLoginTestScreen extends StatefulWidget {
  final AuthService authService;

  const KakaoLoginTestScreen({super.key, required this.authService});

  @override
  State<KakaoLoginTestScreen> createState() => _KakaoLoginTestScreenState();
}

class _KakaoLoginTestScreenState extends State<KakaoLoginTestScreen> {
  bool _isLoggedIn = false;
  String? _accessToken;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await widget.authService.isLoggedIn();
    final token = await widget.authService.getAccessToken();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _accessToken = token;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.loginWithKakao();
      await _checkLoginStatus();
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) {
        _setError('로그인이 취소되었습니다.');
      } else {
        _setError('카카오 로그인 실패: ${e.message}');
      }
    } on KakaoClientException catch (e) {
      _setError('카카오 SDK 오류: ${e.message}');
    } catch (e) {
      _setError('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.logout();
      await _checkLoginStatus();
    } catch (e) {
      _setError('로그아웃 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  String _maskToken(String token) {
    if (token.length <= 10) return '***';
    return '${token.substring(0, 10)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오 로그인 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(isLoggedIn: _isLoggedIn),
            const SizedBox(height: 16),
            if (_accessToken != null) ...[
              _TokenCard(maskedToken: _maskToken(_accessToken!)),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              _ErrorCard(message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (!_isLoggedIn)
                ElevatedButton(
                  onPressed: _login,
                  style: AppButtonStyles.kakao().copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  child: const Text(
                    '카카오 로그인',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (_isLoggedIn)
                OutlinedButton(
                  onPressed: _logout,
                  style: AppButtonStyles.outlined().copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  child: const Text('로그아웃'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isLoggedIn;

  const _StatusCard({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isLoggedIn ? Icons.check_circle : Icons.cancel,
              color: isLoggedIn ? AppColors.ink : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              '로그인 상태: ${isLoggedIn ? '로그인됨' : '로그아웃'}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  final String maskedToken;

  const _TokenCard({required this.maskedToken});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Access Token',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(maskedToken, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF1F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: AppErrorText(message)),
          ],
        ),
      ),
    );
  }
}
