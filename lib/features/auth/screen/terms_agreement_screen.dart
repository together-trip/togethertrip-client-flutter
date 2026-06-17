import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../../trip/service/trip_service.dart';
import '../service/auth_service.dart';
import '../service/terms_agreement_service.dart';
import 'sign_up_profile_screen.dart';
import 'terms_list_screen.dart';

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
    _termsFuture = widget.termsAgreementService.getRequiredTerms();
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

  void _showTermsDetail(TermsAgreementItem term) {
    showTermsDetailSheet(context: context, term: term);
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
                  _termsFuture = widget.termsAgreementService
                      .getRequiredTerms();
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
                      for (final term in terms)
                        _TermsTile(
                          term: term,
                          value: _agreedCodes.contains(term.code),
                          onChanged: (checked) => _toggleOne(term, checked),
                          onDetail: () => _showTermsDetail(term),
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

class _AllTermsTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AllTermsTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: AppColors.ink),
        borderRadius: AppRadii.controlRadius,
      ),
      child: CheckboxListTile(
        key: const ValueKey('agreeAllTermsCheckbox'),
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.ink,
        title: const Text(
          '전체 동의',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('필수 약관을 한 번에 선택합니다.'),
      ),
    );
  }
}

class _TermsTile extends StatelessWidget {
  final TermsAgreementItem term;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDetail;

  const _TermsTile({
    required this.term,
    required this.value,
    required this.onChanged,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: AppRadii.controlRadius,
        ),
        child: Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                value: value,
                onChanged: onChanged,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.ink,
                title: Text(
                  '${term.required ? '[필수] ' : '[선택] '}${term.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('버전 ${term.version}'),
              ),
            ),
            IconButton(
              tooltip: '${term.title} 보기',
              onPressed: onDetail,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 4),
          ],
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
