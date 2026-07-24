import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../main/screen/main_shell_screen.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/profile_image_input_helper.dart';
import '../service/terms_agreement_service.dart';
import 'terms_list_screen.dart';
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
  final TermsAgreementService? termsAgreementService;
  final String? temporaryToken;
  final bool restoreExistingTerms;
  final UserProfile? prefillProfile;
  final Set<String>? initialAgreedTermCodes;

  /// 값이 있으면 "개인정보 수정" 모드로 동작하며 기존 내용을 프리필한다.
  /// null이면 회원가입 프로필 설정 모드.
  final UserProfile? initialProfile;

  const SignUpProfileScreen({
    super.key,
    required this.authService,
    this.tripService,
    this.termsAgreementService,
    required this.temporaryToken,
    this.initialProfile,
    this.prefillProfile,
    this.restoreExistingTerms = false,
    this.initialAgreedTermCodes,
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

  late final TermsAgreementService _termsAgreementService;
  Future<List<TermsAgreementItem>>? _termsFuture;
  final Set<String> _agreedTermCodes = {};
  _Gender _gender = _Gender.male;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _requestedPhoneNumber;
  ProfileImageInput? _selectedProfileImage;
  String? _checkedNickname;
  String _lastNicknameText = '';
  bool? _isNicknameAvailable;
  String? _nicknameMessage;
  bool _isCheckingNickname = false;
  bool _isRequestingCode = false;
  bool _isConfirmingCode = false;
  bool _isSubmitting = false;
  bool _isPhoneVerified = false;
  String? _errorMessage;

  bool get _isCodeRequested => _remainingSeconds > 0;
  bool get _requiresPhoneVerification => widget.temporaryToken != null;
  bool get _isEditMode => widget.initialProfile != null;
  UserProfile? get _profileForPrefill =>
      widget.initialProfile ?? widget.prefillProfile;
  bool get _shouldCollectTerms => !_isEditMode;
  bool get _isNicknameConfirmed {
    return _isNicknameAvailable == true &&
        _checkedNickname == _currentNickname();
  }

  @override
  void initState() {
    super.initState();
    _termsAgreementService =
        widget.termsAgreementService ??
        TermsAgreementService(authService: widget.authService);
    if (_shouldCollectTerms) {
      _agreedTermCodes.addAll(widget.initialAgreedTermCodes ?? const {});
      _termsFuture = _loadTermsForSignup();
    }
    _isPhoneVerified = !_requiresPhoneVerification;
    _prefillFromInitialProfile();
    _lastNicknameText = _currentNickname();
    _phoneController.addListener(_resetVerificationIfPhoneChanged);
  }

  void _prefillFromInitialProfile() {
    final profile = _profileForPrefill;
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

      final currentPhoneNumber = _toApiPhoneNumber(_phoneController.text);
      if (currentPhoneNumber != requestedPhoneNumber) {
        setState(() {
          _requestedPhoneNumber = null;
          _isPhoneVerified = false;
          _codeController.clear();
          _errorMessage = '전화번호가 변경되었습니다. 인증번호를 다시 요청해주세요.';
        });
        return;
      }

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

    final confirmingPhoneNumber = _requestedPhoneNumber!;
    try {
      await widget.authService.confirmPhoneVerification(
        temporaryToken: temporaryToken,
        phoneNumber: confirmingPhoneNumber,
        code: code,
      );
      if (!mounted) return;

      final currentPhoneNumber = _toApiPhoneNumber(_phoneController.text);
      if (_requestedPhoneNumber != confirmingPhoneNumber ||
          currentPhoneNumber != confirmingPhoneNumber) {
        setState(() {
          _isPhoneVerified = false;
          _errorMessage = '전화번호가 변경되었습니다. 인증번호를 다시 요청해주세요.';
        });
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
    final nickname = _currentNickname();
    final nicknameError = _validateNickname(nickname);
    if (nicknameError != null) {
      setState(() => _nicknameMessage = nicknameError);
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _errorMessage = null;
      _nicknameMessage = null;
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
        _lastNicknameText = nickname;
        _isNicknameAvailable = isAvailable;
        _nicknameMessage = isAvailable ? null : '이미 사용 중인 닉네임입니다.';
      });
    } on ApiException catch (e) {
      setState(() => _nicknameMessage = e.message);
    } catch (e) {
      setState(() => _nicknameMessage = '닉네임 확인에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isCheckingNickname = false);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final mimeType =
          picked.mimeType ?? inferProfileImageMimeType(picked.name);
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
    } on PlatformException catch (e) {
      setState(
        () => _errorMessage = e.message ?? '사진을 선택할 수 없습니다. 권한을 확인해주세요.',
      );
    } catch (e) {
      setState(() => _errorMessage = '사진을 선택할 수 없습니다: $e');
      return;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_isPhoneVerified) {
      setState(() => _errorMessage = '전화번호 인증을 완료해주세요.');
      return;
    }

    if (!_isNicknameConfirmed) {
      setState(() => _nicknameMessage = '닉네임 중복 확인을 완료해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final terms = await _validateTermsAgreement();
    if (terms == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final nickname = _currentNickname();
      if (_shouldCollectTerms) {
        try {
          await _termsAgreementService.saveAgreements(
            agreedTerms: terms
                .where((term) => _agreedTermCodes.contains(term.code))
                .toList(),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _errorMessage = '약관 동의 저장에 실패했습니다: $e');
          return;
        }
      }
      await widget.authService.updateMyProfile(
        nickname: nickname,
        gender: _gender.apiValue,
        birthDate: _toApiBirthDate(_birthDateController.text),
        profileImageUrl: _profileForPrefill?.profileImageUrl,
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
            termsAgreementService: widget.termsAgreementService,
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

  void _handleNicknameChanged() {
    final currentNickname = _currentNickname();
    if (currentNickname == _lastNicknameText) return;
    _lastNicknameText = currentNickname;

    setState(() {
      _checkedNickname = null;
      _isNicknameAvailable = null;
      _nicknameMessage = null;
    });
  }

  String _currentNickname() {
    return _nicknameController.text.trim();
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

  bool _hasAgreedAllRequired(List<TermsAgreementItem> terms) {
    final requiredTerms = terms.where((term) => term.required).toList();
    return requiredTerms.isNotEmpty &&
        requiredTerms.every((term) => _agreedTermCodes.contains(term.code));
  }

  Future<List<TermsAgreementItem>> _loadTermsForSignup() async {
    final terms = await _termsAgreementService.getTerms();
    if (_requiresPhoneVerification || !widget.restoreExistingTerms) {
      return terms;
    }

    final agreedCodes = await _termsAgreementService.getAgreedTermCodes();
    if (agreedCodes.isEmpty) return terms;

    if (mounted) {
      setState(() {
        _agreedTermCodes
          ..clear()
          ..addAll(agreedCodes);
      });
    } else {
      _agreedTermCodes
        ..clear()
        ..addAll(agreedCodes);
    }
    return terms;
  }

  Future<List<TermsAgreementItem>?> _validateTermsAgreement() async {
    if (!_shouldCollectTerms) return const <TermsAgreementItem>[];

    try {
      final terms = await (_termsFuture ?? _termsAgreementService.getTerms());
      if (!_hasAgreedAllRequired(terms)) {
        setState(() => _errorMessage = '필수 약관에 동의해주세요.');
        return null;
      }
      return terms;
    } catch (e) {
      setState(() => _errorMessage = '약관을 불러오지 못했습니다: $e');
      return null;
    }
  }

  void _toggleAllTerms(List<TermsAgreementItem> terms, bool? checked) {
    setState(() {
      if (checked == true) {
        _agreedTermCodes
          ..clear()
          ..addAll(terms.map((term) => term.code));
      } else {
        _agreedTermCodes.clear();
      }
    });
  }

  void _toggleTerm(TermsAgreementItem term, bool? checked) {
    setState(() {
      if (checked == true) {
        _agreedTermCodes.add(term.code);
      } else {
        _agreedTermCodes.remove(term.code);
      }
    });
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
                          nickname: _currentNickname(),
                          currentImageUrl: _profileForPrefill?.profileImageUrl,
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
                                    onChanged: (_) => _handleNicknameChanged(),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
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
                                            : AppColors.brand,
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
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (_nicknameMessage != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _nicknameMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
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
                                                  AppColors.brand,
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
                      if (_shouldCollectTerms)
                        _TermsAgreementSection(
                          termsFuture: _termsFuture!,
                          agreedCodes: _agreedTermCodes,
                          onToggleAll: _toggleAllTerms,
                          onToggleTerm: _toggleTerm,
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

class _TermsAgreementSection extends StatelessWidget {
  final Future<List<TermsAgreementItem>> termsFuture;
  final Set<String> agreedCodes;
  final void Function(List<TermsAgreementItem> terms, bool? checked)
  onToggleAll;
  final void Function(TermsAgreementItem term, bool? checked) onToggleTerm;

  const _TermsAgreementSection({
    required this.termsFuture,
    required this.agreedCodes,
    required this.onToggleAll,
    required this.onToggleTerm,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TermsAgreementItem>>(
      future: termsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: AppErrorText('약관을 불러오지 못했습니다.'),
          );
        }

        final terms = snapshot.data ?? const <TermsAgreementItem>[];
        final agreedAll =
            terms.isNotEmpty &&
            terms.every((term) => agreedCodes.contains(term.code));
        final requiredTerms = terms.where((term) => term.required).toList();
        final agreedRequired =
            requiredTerms.isNotEmpty &&
            requiredTerms.every((term) => agreedCodes.contains(term.code));

        return LabeledField(
          label: '약관 동의',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TermsCheckboxRow(
                key: const ValueKey('agreeAllTermsCheckbox'),
                title: '전체 동의',
                subtitle: agreedAll
                    ? '모든 약관에 동의했습니다.'
                    : agreedRequired
                    ? '필수 약관 동의가 완료되었습니다.'
                    : '필수 및 선택 약관에 모두 동의합니다.',
                value: agreedAll,
                onChanged: (checked) => onToggleAll(terms, checked),
                emphasized: true,
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: AppColors.lineSoft),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < terms.length; index++) ...[
                      _TermsCheckboxRow(
                        key: ValueKey('termsCheckbox_${terms[index].code}'),
                        title: terms[index].title,
                        subtitle: '버전 ${terms[index].version}',
                        value: agreedCodes.contains(terms[index].code),
                        onChanged: (checked) =>
                            onToggleTerm(terms[index], checked),
                        onView: () => showTermsDetailSheet(
                          context: context,
                          term: terms[index],
                        ),
                        required: terms[index].required,
                      ),
                      if (index < terms.length - 1)
                        const Divider(height: 1, color: AppColors.lineSoft),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                agreedRequired ? '필수 약관 동의 완료' : '필수 약관에 모두 동의해야 가입할 수 있어요.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: agreedRequired ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TermsCheckboxRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onView;
  final bool? required;
  final bool emphasized;

  const _TermsCheckboxRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onView,
    this.required,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = emphasized && value
        ? AppColors.brandSoft
        : AppColors.surface;

    return Material(
      color: backgroundColor,
      borderRadius: AppRadii.controlRadius,
      child: InkWell(
        borderRadius: AppRadii.controlRadius,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            emphasized ? 10 : 8,
            8,
            emphasized ? 10 : 8,
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              if (required != null) ...[
                _InlineRequirementBadge(required: required!),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: emphasized
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (onView != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('termsDetailButton_$title'),
                  tooltip: '약관 보기',
                  onPressed: onView,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  color: AppColors.textSubtle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineRequirementBadge extends StatelessWidget {
  final bool required;

  const _InlineRequirementBadge({required this.required});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: required ? AppColors.brandSoft : AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(6),
        border: required ? null : Border.all(color: AppColors.lineSoft),
      ),
      child: Text(
        required ? '필수' : '선택',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: required ? AppColors.brandStrong : AppColors.textSubtle,
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
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(12),
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
              color: phoneVerified ? AppColors.success : AppColors.textMuted,
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
  final parsed = _parseDisplayBirthDate(birthDate);
  if (parsed == null) {
    return '올바른 생년월일을 입력해주세요.';
  }
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  if (parsed.isAfter(todayOnly)) {
    return '생년월일은 오늘 또는 이전 날짜로 입력해주세요.';
  }
  return null;
}

DateTime? _parseDisplayBirthDate(String value) {
  final parts = value.split('.');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (year < 1900 || month < 1 || month > 12 || day < 1) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
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
