import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../main/screen/main_shell_screen.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/profile_image_input_helper.dart';
import '../widget/profile_form_fields.dart';
import '../widget/profile_image_picker.dart';
import '../widget/profile_input_formatters.dart';

enum _Gender {
  male('남자', 'MALE'),
  female('여자', 'FEMALE');

  final String label;
  final String apiValue;

  const _Gender(this.label, this.apiValue);
}

class SignUpProfileScreen extends StatefulWidget {
  final AuthService authService;
  final TripService? tripService;
  final String? temporaryToken;

  /// 값이 있으면 "개인정보 수정" 모드로 동작하며 기존 내용을 프리필한다.
  /// null이면 회원가입 프로필 설정 모드.
  final UserProfile? initialProfile;

  const SignUpProfileScreen({
    super.key,
    required this.authService,
    this.tripService,
    required this.temporaryToken,
    this.initialProfile,
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
  final _imagePicker = ImagePicker();

  _Gender _gender = _Gender.male;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _requestedPhoneNumber;
  ProfileImageInput? _selectedProfileImage;
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
  bool get _isEditMode => widget.initialProfile != null;
  bool get _isNicknameConfirmed {
    return _isNicknameAvailable == true &&
        _checkedNickname == _nicknameController.text.trim();
  }

  @override
  void initState() {
    super.initState();
    _isPhoneVerified = !_requiresPhoneVerification;
    _prefillFromInitialProfile();
    _nicknameController.addListener(_resetNicknameCheckIfChanged);
    _phoneController.addListener(_resetVerificationIfPhoneChanged);
  }

  void _prefillFromInitialProfile() {
    final profile = widget.initialProfile;
    if (profile == null) return;

    _nicknameController.text = profile.nickname;
    // 기존 닉네임은 본인 것이므로 중복확인 없이 확인된 상태로 간주한다.
    // (공개 중복확인 API는 본인 닉네임도 "사용중"으로 보기 때문)
    _checkedNickname = profile.nickname;
    _isNicknameAvailable = true;

    if (profile.gender == _Gender.female.apiValue) {
      _gender = _Gender.female;
    } else if (profile.gender == _Gender.male.apiValue) {
      _gender = _Gender.male;
    }

    final birthDate = profile.birthDate;
    if (birthDate != null && birthDate.isNotEmpty) {
      _birthDateController.text = _toDisplayBirthDate(birthDate);
    }
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
      final requestedPhoneNumber = _toApiPhoneNumber(_phoneController.text);
      final result = await widget.authService.requestPhoneVerification(
        temporaryToken: temporaryToken,
        phoneNumber: requestedPhoneNumber,
      );
      if (!mounted) return;

      setState(() {
        _requestedPhoneNumber = requestedPhoneNumber;
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
      final result = await widget.authService.confirmPhoneVerification(
        temporaryToken: temporaryToken,
        phoneNumber: _requestedPhoneNumber!,
        code: code,
      );
      if (!mounted) return;

      if (result.isAuthenticated) {
        _timer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MainShellScreen(
              authService: widget.authService,
              tripService: widget.tripService,
            ),
          ),
          (_) => false,
        );
        return;
      }

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

  Future<void> _pickProfileImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final mimeType = picked.mimeType ?? inferProfileImageMimeType(picked.name);
    final hasAllowedNameAndMime = isSupportedProfileImageNameAndMime(
      picked.name,
      mimeType,
    );
    final hasAllowedSignature = await hasSupportedProfileImageSignature(
      picked.path,
    );
    if (!hasAllowedNameAndMime || !hasAllowedSignature) {
      setState(() => _errorMessage = '프로필 이미지는 JPG 또는 PNG만 사용할 수 있습니다.');
      return;
    }

    setState(() {
      _selectedProfileImage = ProfileImageInput(
        path: picked.path,
        filename: picked.name,
        mimeType: mimeType,
      );
      _errorMessage = null;
    });
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
        profileImageUrl: widget.initialProfile?.profileImageUrl,
        profileImage: _selectedProfileImage,
      );
      if (!mounted) return;

      if (_isEditMode) {
        // 수정 모드: 호출한 화면(마이페이지)으로 결과를 전달하며 닫는다.
        Navigator.of(context).pop(true);
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MainShellScreen(
            authService: widget.authService,
            tripService: widget.tripService,
          ),
        ),
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
    if (_toApiPhoneNumber(currentPhone) == _requestedPhoneNumber) return;

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 24),
          color: AppColors.ink,
        ),
        title: Text(
          _isEditMode ? '개인정보 수정' : '프로필 설정',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LabeledField(
                        label: '프로필 이미지',
                        child: ProfileImagePicker(
                          nickname: _nicknameController.text.trim(),
                          currentImageUrl:
                              widget.initialProfile?.profileImageUrl,
                          selectedImage: _selectedProfileImage,
                          onPick: _pickProfileImage,
                        ),
                      ),
                      LabeledField(
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
                                      hintText: '2~20자, 한글/영문/숫자',
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
                                    style: AppButtonStyles.outlined().copyWith(
                                      backgroundColor: WidgetStatePropertyAll(
                                        _isNicknameConfirmed
                                            ? AppColors.surface
                                            : AppColors.ink,
                                      ),
                                      foregroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return AppColors.textMuted;
                                            }
                                            return _isNicknameConfirmed
                                                ? AppColors.ink
                                                : Colors.white;
                                          }),
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
                                  color: AppColors.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      LabeledField(
                        label: '성별',
                        child: Row(
                          children: [
                            Expanded(
                              child: GenderButton(
                                label: _Gender.male.label,
                                isSelected: _gender == _Gender.male,
                                onPressed: () =>
                                    setState(() => _gender = _Gender.male),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GenderButton(
                                label: _Gender.female.label,
                                isSelected: _gender == _Gender.female,
                                onPressed: () =>
                                    setState(() => _gender = _Gender.female),
                              ),
                            ),
                          ],
                        ),
                      ),
                      LabeledField(
                        label: '생년월일',
                        child: TextFormField(
                          key: const ValueKey('birthDateField'),
                          controller: _birthDateController,
                          decoration: const InputDecoration(
                            hintText: 'YYYY.MM.DD',
                          ),
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          inputFormatters: const [BirthDateInputFormatter()],
                          validator: _validateBirthDate,
                        ),
                      ),
                      if (_isEditMode)
                        LabeledField(
                          label: '전화번호',
                          child: _ReadOnlyPhoneInfo(
                            phoneNumberMasked:
                                widget.initialProfile?.phoneNumberMasked,
                            phoneVerified:
                                widget.initialProfile?.phoneVerified ?? false,
                          ),
                        ),
                      if (_requiresPhoneVerification)
                        LabeledField(
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
                                        PhoneNumberInputFormatter(),
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
                                      style: AppButtonStyles.outlined()
                                          .copyWith(
                                            backgroundColor:
                                                const WidgetStatePropertyAll(
                                                  AppColors.ink,
                                                ),
                                            foregroundColor:
                                                WidgetStateProperty.resolveWith(
                                                  (states) {
                                                    if (states.contains(
                                                      WidgetState.disabled,
                                                    )) {
                                                      return AppColors
                                                          .textMuted;
                                                    }
                                                    return Colors.white;
                                                  },
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
                                        style: AppButtonStyles.outlined(),
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
                        AppErrorText(_errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const ValueKey('submitButton'),
                          onPressed: _isSubmitting ? null : _submit,
                          style: AppButtonStyles.elevatedPrimary(),
                          child: Text(
                            _isSubmitting
                                ? '저장중'
                                : _isEditMode
                                ? '저장'
                                : '완료',
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

class _ReadOnlyPhoneInfo extends StatelessWidget {
  final String? phoneNumberMasked;
  final bool phoneVerified;

  const _ReadOnlyPhoneInfo({
    required this.phoneNumberMasked,
    required this.phoneVerified,
  });

  @override
  Widget build(BuildContext context) {
    final phoneText = phoneNumberMasked != null && phoneNumberMasked!.isNotEmpty
        ? phoneNumberMasked!
        : '인증된 전화번호 없음';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              phoneText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            phoneVerified ? '인증 완료' : '미인증',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: phoneVerified ? AppColors.ink : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

String? _validateNickname(String? value) {
  final nickname = value?.trim() ?? '';
  if (nickname.isEmpty) return '닉네임을 입력해주세요.';
  if (nickname.length < 2 || nickname.length > 20) {
    return '닉네임은 2~20자로 입력해주세요.';
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
  final digits = digitsOnly(value);
  if (digits.length != 8) return value.trim().replaceAll('.', '-');
  return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
}

String _toDisplayBirthDate(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 8) return value.trim().replaceAll('-', '.');
  return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)}';
}

String _toApiPhoneNumber(String value) {
  return digitsOnly(value);
}

String? _validatePhoneNumber(String? value) {
  final phoneNumber = value?.trim() ?? '';
  if (phoneNumber.isEmpty) return '전화번호를 입력해주세요.';
  if (!RegExp(r'^010-?\d{4}-?\d{4}$').hasMatch(phoneNumber)) {
    return '전화번호는 010-0000-0000 형식으로 입력해주세요.';
  }
  return null;
}
