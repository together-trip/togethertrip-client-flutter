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

class SignUpProfileScreen extends StatefulWidget {
  final AuthService authService;
  final TripService? tripService;
  final TermsAgreementService? termsAgreementService;
  final bool restoreExistingTerms;
  final UserProfile? prefillProfile;
  final Set<String>? initialAgreedTermCodes;

  /// 값이 있으면 "프로필 수정" 모드로 동작하며 기존 내용을 프리필한다.
  /// null이면 회원가입 프로필 설정 모드.
  final UserProfile? initialProfile;

  const SignUpProfileScreen({
    super.key,
    required this.authService,
    this.tripService,
    this.termsAgreementService,
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
  final _imagePicker = ImagePicker();

  late final TermsAgreementService _termsAgreementService;
  Future<List<TermsAgreementItem>>? _termsFuture;
  final Set<String> _agreedTermCodes = {};
  ProfileImageInput? _selectedProfileImage;
  String? _checkedNickname;
  String _lastNicknameText = '';
  bool? _isNicknameAvailable;
  String? _nicknameMessage;
  bool _isCheckingNickname = false;
  bool _isSubmitting = false;
  String? _errorMessage;

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
    _prefillFromInitialProfile();
    _lastNicknameText = _currentNickname();
  }

  void _prefillFromInitialProfile() {
    final profile = _profileForPrefill;
    if (profile == null) return;

    _nicknameController.text = profile.nickname;
    // 기존 닉네임은 본인 것이므로 중복확인 없이 확인된 상태로 간주한다.
    // (공개 중복확인 API는 본인 닉네임도 "사용중"으로 보기 때문)
    _checkedNickname = profile.nickname;
    _isNicknameAvailable = true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
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

  bool _hasAgreedAllRequired(List<TermsAgreementItem> terms) {
    final requiredTerms = terms.where((term) => term.required).toList();
    return requiredTerms.isNotEmpty &&
        requiredTerms.every((term) => _agreedTermCodes.contains(term.code));
  }

  Future<List<TermsAgreementItem>> _loadTermsForSignup() async {
    final terms = await _termsAgreementService.getTerms();
    if (!widget.restoreExistingTerms) {
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
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          color: AppColors.ink,
        ),
        title: Text(
          _isEditMode ? '프로필 수정' : '프로필 설정',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEditMode) ...[
                        const Text(
                          '가입 정보를 입력해주세요',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          '닉네임을 설정하면 바로 시작할 수 있어요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      ProfileImagePicker(
                        nickname: _currentNickname(),
                        currentImageUrl: _profileForPrefill?.profileImageUrl,
                        selectedImage: _selectedProfileImage,
                        onPick: _pickProfileImage,
                      ),
                      const SizedBox(height: 22),
                      if (_isEditMode) ...[
                        const _ProfileSectionHeading(label: '기본 정보'),
                        const SizedBox(height: 10),
                      ],
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
                                    decoration: AppInputDecorations.filled(
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
                                            ? AppColors.brandSoft
                                            : AppColors.neutralSoft,
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
                                                ? AppColors.brandStrong
                                                : AppColors.ink;
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
                    ],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.lineSoft)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      key: const ValueKey('submitButton'),
                      onPressed: _isSubmitting ? null : _submit,
                      style: AppButtonStyles.elevatedPrimary(radius: 12),
                      child: Text(
                        _isSubmitting
                            ? '저장중'
                            : _isEditMode
                            ? '변경사항 저장'
                            : '완료',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
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

class _ProfileSectionHeading extends StatelessWidget {
  final String label;

  const _ProfileSectionHeading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.caption);
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
        final optionalTerms = terms.where((term) => !term.required).toList();
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
              const SizedBox(height: 14),
              _TermsGroup(
                label: '필수 약관',
                terms: requiredTerms,
                agreedCodes: agreedCodes,
                onToggleTerm: onToggleTerm,
              ),
              if (optionalTerms.isNotEmpty) ...[
                const SizedBox(height: 14),
                _TermsGroup(
                  label: '선택 약관',
                  terms: optionalTerms,
                  agreedCodes: agreedCodes,
                  onToggleTerm: onToggleTerm,
                ),
              ],
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

class _TermsGroup extends StatelessWidget {
  final String label;
  final List<TermsAgreementItem> terms;
  final Set<String> agreedCodes;
  final void Function(TermsAgreementItem term, bool? checked) onToggleTerm;

  const _TermsGroup({
    required this.label,
    required this.terms,
    required this.agreedCodes,
    required this.onToggleTerm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 6),
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
                  value: agreedCodes.contains(terms[index].code),
                  onChanged: (checked) => onToggleTerm(terms[index], checked),
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
      ],
    );
  }
}

class _TermsCheckboxRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onView;
  final bool? required;
  final bool emphasized;

  const _TermsCheckboxRow({
    super.key,
    required this.title,
    this.subtitle,
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onView != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('termsDetailButton_$title'),
                  tooltip: '약관 보기',
                  onPressed: onView,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
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
