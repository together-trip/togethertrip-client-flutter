import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/terms_agreement_service.dart';
import 'sign_up_profile_screen.dart';

class TermsAgreementScreen extends StatefulWidget {
  final AuthService authService;
  final TripService? tripService;
  final TermsAgreementService termsAgreementService;
  final AuthLoginResult loginResult;

  const TermsAgreementScreen({
    super.key,
    required this.authService,
    this.tripService,
    required this.termsAgreementService,
    required this.loginResult,
  });

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  late Future<List<TermsAgreementItem>> _termsFuture;
  final Set<String> _agreedCodes = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _termsFuture = widget.termsAgreementService.getTerms();
  }

  bool _hasAgreedAllRequired(List<TermsAgreementItem> terms) {
    return terms
        .where((term) => term.required)
        .every((term) => _agreedCodes.contains(term.code));
  }

  Future<void> _continue(List<TermsAgreementItem> terms) async {
    if (!_hasAgreedAllRequired(terms) || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final agreedTerms = terms
          .where((term) => _agreedCodes.contains(term.code))
          .toList();
      await widget.termsAgreementService.saveAgreements(
        agreedTerms: agreedTerms,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SignUpProfileScreen(
            authService: widget.authService,
            tripService: widget.tripService,
            termsAgreementService: widget.termsAgreementService,
            temporaryToken: widget.loginResult.temporaryToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '약관 동의 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleAll(List<TermsAgreementItem> terms, bool? checked) {
    setState(() {
      if (checked == true) {
        _agreedCodes
          ..clear()
          ..addAll(terms.map((term) => term.code));
      } else {
        _agreedCodes.clear();
      }
    });
  }

  void _toggleOne(TermsAgreementItem term, bool? checked) {
    setState(() {
      if (checked == true) {
        _agreedCodes.add(term.code);
      } else {
        _agreedCodes.remove(term.code);
      }
    });
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
        title: const Text('약관 동의', style: AppTextStyles.screenTitle),
      ),
      body: FutureBuilder<List<TermsAgreementItem>>(
        future: _termsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _TermsErrorState(
              message: '약관을 불러오지 못했습니다.',
              onRetry: () {
                setState(() {
                  _errorMessage = null;
                  _termsFuture = widget.termsAgreementService.getTerms();
                });
              },
            );
          }

          final terms = snapshot.data ?? const <TermsAgreementItem>[];
          final agreedAll =
              terms.isNotEmpty &&
              terms.every((term) => _agreedCodes.contains(term.code));
          final canContinue = _hasAgreedAllRequired(terms);

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
                    children: [
                      const Text(
                        '회원가입을 위해\n필수 약관에 동의해주세요',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '동의 후 프로필 설정으로 이동합니다. 약관 전문은 마이페이지에서도 다시 확인할 수 있어요.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AllTermsTile(
                        value: agreedAll,
                        onChanged: (checked) => _toggleAll(terms, checked),
                      ),
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.controlRadius,
                        ),
                        child: Column(
                          children: [
                            for (var index = 0; index < terms.length; index++)
                              _TermsTile(
                                term: terms[index],
                                value: _agreedCodes.contains(terms[index].code),
                                showDivider: index < terms.length - 1,
                                onChanged: (checked) =>
                                    _toggleOne(terms[index], checked),
                              ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('continueTermsButton'),
                      onPressed: canContinue && !_isSaving
                          ? () => _continue(terms)
                          : null,
                      style: AppButtonStyles.primary(),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '동의하고 계속하기',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AllTermsTile extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AllTermsTile({required this.value, required this.onChanged});

  @override
  State<_AllTermsTile> createState() => _AllTermsTileState();
}

class _AllTermsTileState extends State<_AllTermsTile> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onChanged(!widget.value),
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          borderRadius: AppRadii.controlRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: widget.value ? const Color(0xFFF4F7F4) : AppColors.surface,
              border: Border.all(
                color: widget.value
                    ? const Color(0xFFC9D8C9)
                    : AppColors.lineSoft,
              ),
              borderRadius: AppRadii.controlRadius,
            ),
            child: Row(
              children: [
                Checkbox(
                  key: const ValueKey('agreeAllTermsCheckbox'),
                  value: widget.value,
                  onChanged: widget.onChanged,
                  activeColor: AppColors.ink,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 동의',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '필수와 선택 약관을 한 번에 선택합니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
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

class _TermsTile extends StatefulWidget {
  final TermsAgreementItem term;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool?> onChanged;

  const _TermsTile({
    required this.term,
    required this.value,
    required this.showDivider,
    required this.onChanged,
  });

  @override
  State<_TermsTile> createState() => _TermsTileState();
}

class _TermsTileState extends State<_TermsTile> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onChanged(!widget.value),
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          borderRadius: AppRadii.controlRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            color: _pressed ? Colors.white : Colors.transparent,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: Row(
                    children: [
                      Checkbox(
                        key: ValueKey('termsCheckbox_${widget.term.code}'),
                        value: widget.value,
                        onChanged: widget.onChanged,
                        activeColor: AppColors.ink,
                      ),
                      const SizedBox(width: 6),
                      _TermRequirementBadge(required: widget.term.required),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.term.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: Text(
                                widget.value
                                    ? '동의함 · 버전 ${widget.term.version}'
                                    : '미동의 · 버전 ${widget.term.version}',
                                key: ValueKey(
                                  '${widget.term.code}_${widget.value}',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showDivider)
                  const Padding(
                    padding: EdgeInsets.only(left: 66),
                    child: Divider(height: 1, color: AppColors.lineSoft),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermRequirementBadge extends StatelessWidget {
  final bool required;

  const _TermRequirementBadge({required this.required});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: required ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: required ? null : Border.all(color: AppColors.lineSoft),
      ),
      child: Text(
        required ? '필수' : '선택',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: required ? Colors.white : AppColors.textSubtle,
        ),
      ),
    );
  }
}

class _TermsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TermsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
