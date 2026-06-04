import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../main/screen/main_placeholder_screen.dart';
import '../service/auth_service.dart';

enum _Gender {
  male('남자', 'MALE'),
  female('여자', 'FEMALE');

  final String label;
  final String apiValue;

  const _Gender(this.label, this.apiValue);
}

class SignUpProfileScreen extends StatefulWidget {
  final AuthService authService;
  final String? temporaryToken;

  const SignUpProfileScreen({
    super.key,
    required this.authService,
    required this.temporaryToken,
  });

  @override
  State<SignUpProfileScreen> createState() => _SignUpProfileScreenState();
}

class _SignUpProfileScreenState extends State<SignUpProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  _Gender _gender = _Gender.male;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _requestedPhoneNumber;
  String? _checkedNickname;
  bool? _isNicknameAvailable;
  bool _isCheckingNickname = false;
  bool _isRequestingCode = false;
  bool _isConfirmingCode = false;
  bool _isSubmitting = false;
  bool _isPhoneVerified = false;
  String? _errorMessage;

  bool get _isCodeRequested => _remainingSeconds > 0;
  bool get _requiresPhoneVerification => widget.temporaryToken != null;
  bool get _isNicknameConfirmed {
    return _isNicknameAvailable == true &&
        _checkedNickname == _nicknameController.text.trim();
  }

  @override
  void initState() {
    super.initState();
    _isPhoneVerified = !_requiresPhoneVerification;
    _nicknameController.addListener(_resetNicknameCheckIfChanged);
    _phoneController.addListener(_resetVerificationIfPhoneChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nicknameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final temporaryToken = widget.temporaryToken;
    if (temporaryToken == null) return;

    final phoneError = _validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      setState(() => _errorMessage = phoneError);
      return;
    }

    setState(() {
      _isRequestingCode = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.requestPhoneVerification(
        temporaryToken: temporaryToken,
        phoneNumber: _toApiPhoneNumber(_phoneController.text),
      );
      if (!mounted) return;

      setState(() {
        _requestedPhoneNumber = result.phoneNumber;
        _isPhoneVerified = false;
        _codeController.clear();
      });
      _startTimer(result.expiresInSeconds);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '인증번호 요청에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isRequestingCode = false);
    }
  }

  Future<void> _confirmCode() async {
    final temporaryToken = widget.temporaryToken;
    if (temporaryToken == null) return;

    final code = _codeController.text.trim();
    if (!_isCodeRequested || _requestedPhoneNumber == null) {
      setState(() => _errorMessage = '인증번호를 먼저 요청해주세요.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _errorMessage = '인증번호 6자리를 입력해주세요.');
      return;
    }

    setState(() {
      _isConfirmingCode = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.confirmPhoneVerification(
        temporaryToken: temporaryToken,
        phoneNumber: _requestedPhoneNumber!,
        code: code,
      );
      if (!mounted) return;

      _timer?.cancel();
      setState(() {
        _remainingSeconds = 0;
        _isPhoneVerified = true;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '인증번호 확인에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isConfirmingCode = false);
    }
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    final nicknameError = _validateNickname(nickname);
    if (nicknameError != null) {
      setState(() => _errorMessage = nicknameError);
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _errorMessage = null;
      _isNicknameAvailable = null;
      _checkedNickname = null;
    });

    try {
      final isAvailable = await widget.authService.checkNicknameAvailability(
        nickname,
      );
      if (!mounted) return;

      setState(() {
        _checkedNickname = nickname;
        _isNicknameAvailable = isAvailable;
        _errorMessage = isAvailable ? null : '이미 사용 중인 닉네임입니다.';
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '닉네임 확인에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isCheckingNickname = false);
    }
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_isPhoneVerified) {
      setState(() => _errorMessage = '전화번호 인증을 완료해주세요.');
      return;
    }

    if (!_isNicknameConfirmed) {
      setState(() => _errorMessage = '닉네임 중복 확인을 완료해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final nickname = _nicknameController.text.trim();
      await widget.authService.updateMyProfile(
        nickname: nickname,
        gender: _gender.apiValue,
        birthDate: _toApiBirthDate(_birthDateController.text),
      );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainPlaceholderScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '프로필 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _remainingSeconds = seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        return;
      }

      setState(() => _remainingSeconds -= 1);
    });
  }

  void _resetNicknameCheckIfChanged() {
    if (_checkedNickname == null && _isNicknameAvailable == null) return;

    final currentNickname = _nicknameController.text.trim();
    if (currentNickname == _checkedNickname) return;

    setState(() {
      _checkedNickname = null;
      _isNicknameAvailable = null;
    });
  }

  void _resetVerificationIfPhoneChanged() {
    if (!_requiresPhoneVerification) return;
    if (_requestedPhoneNumber == null && !_isPhoneVerified) return;

    final currentPhone = _phoneController.text.trim();
    if (currentPhone == _requestedPhoneNumber) return;

    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _requestedPhoneNumber = null;
      _isPhoneVerified = false;
      _codeController.clear();
    });
  }

  String _timerText() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(title: '프로필 설정'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabeledField(
                        label: '닉네임',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const ValueKey('nicknameField'),
                                    controller: _nicknameController,
                                    decoration: const InputDecoration(
                                      hintText: '2~12자, 한글/영문/숫자',
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: _validateNickname,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    key: const ValueKey('checkNicknameButton'),
                                    onPressed: _isCheckingNickname
                                        ? null
                                        : _checkNickname,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _isNicknameConfirmed
                                          ? const Color(0xFFEAF7EE)
                                          : const Color(0xFF1A1A1A),
                                      foregroundColor: _isNicknameConfirmed
                                          ? const Color(0xFF16833C)
                                          : Colors.white,
                                      disabledForegroundColor: const Color(
                                        0xFF9E9E9E,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      _isNicknameConfirmed
                                          ? '확인됨'
                                          : _isCheckingNickname
                                          ? '확인중'
                                          : '중복확인',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isNicknameConfirmed) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '사용 가능한 닉네임입니다.',
                                style: TextStyle(
                                  color: Color(0xFF16833C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _LabeledField(
                        label: '성별',
                        child: Row(
                          children: [
                            Expanded(
                              child: _GenderButton(
                                label: _Gender.male.label,
                                isSelected: _gender == _Gender.male,
                                onPressed: () =>
                                    setState(() => _gender = _Gender.male),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GenderButton(
                                label: _Gender.female.label,
                                isSelected: _gender == _Gender.female,
                                onPressed: () =>
                                    setState(() => _gender = _Gender.female),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LabeledField(
                        label: '생년월일',
                        child: TextFormField(
                          key: const ValueKey('birthDateField'),
                          controller: _birthDateController,
                          decoration: const InputDecoration(
                            hintText: 'YYYY.MM.DD',
                          ),
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          inputFormatters: const [_BirthDateInputFormatter()],
                          validator: _validateBirthDate,
                        ),
                      ),
                      if (_requiresPhoneVerification)
                        _LabeledField(
                          label: '전화번호',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      key: const ValueKey('phoneField'),
                                      controller: _phoneController,
                                      decoration: const InputDecoration(
                                        hintText: '010-0000-0000',
                                      ),
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: const [
                                        _PhoneNumberInputFormatter(),
                                      ],
                                      validator: _validatePhoneNumber,
                                      enabled: !_isPhoneVerified,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      key: const ValueKey('requestCodeButton'),
                                      onPressed:
                                          _isRequestingCode || _isPhoneVerified
                                          ? null
                                          : _requestCode,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1A1A1A,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: const Color(
                                          0xFF9E9E9E,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _isPhoneVerified
                                            ? '완료'
                                            : _isRequestingCode
                                            ? '요청중'
                                            : _isCodeRequested
                                            ? '재전송'
                                            : '인증',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isCodeRequested || _isPhoneVerified) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: const ValueKey('codeField'),
                                        controller: _codeController,
                                        decoration: InputDecoration(
                                          hintText: '인증번호 6자리',
                                          suffixText: _isPhoneVerified
                                              ? '인증완료'
                                              : _timerText(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        enabled: !_isPhoneVerified,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 48,
                                      child: OutlinedButton(
                                        key: const ValueKey(
                                          'confirmCodeButton',
                                        ),
                                        onPressed:
                                            _isConfirmingCode ||
                                                _isPhoneVerified
                                            ? null
                                            : _confirmCode,
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _isPhoneVerified
                                              ? '확인됨'
                                              : _isConfirmingCode
                                              ? '확인중'
                                              : '확인',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const ValueKey('submitButton'),
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isSubmitting ? '저장중' : '완료',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 4,
              child: IconButton(
                tooltip: '뒤로',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _GenderButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF1A1A1A),
          side: const BorderSide(color: Color(0xFF1A1A1A)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }
}

String? _validateNickname(String? value) {
  final nickname = value?.trim() ?? '';
  if (nickname.isEmpty) return '닉네임을 입력해주세요.';
  if (nickname.length < 2 || nickname.length > 12) {
    return '닉네임은 2~12자로 입력해주세요.';
  }
  if (!RegExp(r'^[가-힣a-zA-Z0-9]+$').hasMatch(nickname)) {
    return '닉네임은 한글, 영문, 숫자만 사용할 수 있습니다.';
  }
  return null;
}

String? _validateBirthDate(String? value) {
  final birthDate = value?.trim() ?? '';
  if (birthDate.isEmpty) return '생년월일을 입력해주세요.';
  if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(birthDate)) {
    return '생년월일은 YYYY.MM.DD 형식으로 입력해주세요.';
  }
  return null;
}

String _toApiBirthDate(String value) {
  final digits = _digitsOnly(value);
  if (digits.length != 8) return value.trim().replaceAll('.', '-');
  return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
}

String _toApiPhoneNumber(String value) {
  return _digitsOnly(value);
}

String? _validatePhoneNumber(String? value) {
  final phoneNumber = value?.trim() ?? '';
  if (phoneNumber.isEmpty) return '전화번호를 입력해주세요.';
  if (!RegExp(r'^010-?\d{4}-?\d{4}$').hasMatch(phoneNumber)) {
    return '전화번호는 010-0000-0000 형식으로 입력해주세요.';
  }
  return null;
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

class _BirthDateInputFormatter extends TextInputFormatter {
  const _BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOnly(newValue.text);
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = _formatBirthDate(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatBirthDate(String digits) {
    if (digits.length <= 4) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 4)}.${digits.substring(4)}';
    }

    return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6)}';
  }
}

class _PhoneNumberInputFormatter extends TextInputFormatter {
  const _PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _digitsOnly(newValue.text);
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _formatPhoneNumber(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPhoneNumber(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }

    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
}
