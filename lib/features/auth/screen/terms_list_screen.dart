import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../service/terms_agreement_service.dart';

class TermsListScreen extends StatefulWidget {
  final TermsAgreementService termsAgreementService;

  TermsListScreen({super.key, TermsAgreementService? termsAgreementService})
    : termsAgreementService = termsAgreementService ?? TermsAgreementService();

  @override
  State<TermsListScreen> createState() => _TermsListScreenState();
}

class _TermsListScreenState extends State<TermsListScreen> {
  late Future<_TermsListData> _termsFuture;
  final Set<String> _savingCodes = {};

  @override
  void initState() {
    super.initState();
    _termsFuture = _loadTerms();
  }

  Future<_TermsListData> _loadTerms() async {
    final terms = await widget.termsAgreementService.getTerms();
    final agreedCodes = await widget.termsAgreementService.getAgreedTermCodes();
    return _TermsListData(terms: terms, agreedCodes: agreedCodes);
  }

  void _showTermsDetail(TermsAgreementItem term) {
    showTermsDetailSheet(context: context, term: term);
  }

  void _retry() {
    setState(() {
      _termsFuture = _loadTerms();
    });
  }

  Future<void> _toggleOptionalTerm(TermsAgreementItem term, bool agreed) async {
    if (term.required || _savingCodes.contains(term.code)) return;

    setState(() => _savingCodes.add(term.code));
    try {
      await widget.termsAgreementService.updateOptionalAgreement(
        code: term.code,
        agreed: agreed,
      );
      if (!mounted) return;
      setState(() {
        _termsFuture = _loadTerms();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(agreed ? '선택 약관에 동의했습니다.' : '선택 약관 동의를 해제했습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('약관 상태 저장에 실패했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() => _savingCodes.remove(term.code));
      }
    }
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
        title: const Text('약관', style: AppTextStyles.screenTitle),
      ),
      body: FutureBuilder<_TermsListData>(
        future: _termsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _TermsListErrorState(onRetry: _retry);
          }

          final data = snapshot.data ?? const _TermsListData.empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              const Text(
                '서비스 이용에 필요한 약관과 선택 동의 상태를 확인할 수 있어요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < data.terms.length; index++)
                      _TermsMenuRow(
                        term: data.terms[index],
                        agreed: data.agreedCodes.contains(
                          data.terms[index].code,
                        ),
                        isSaving: _savingCodes.contains(data.terms[index].code),
                        showDivider: index < data.terms.length - 1,
                        onTap: () => _showTermsDetail(data.terms[index]),
                        onAgreementChanged: data.terms[index].required
                            ? null
                            : (agreed) => _toggleOptionalTerm(
                                data.terms[index],
                                agreed,
                              ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TermsListData {
  final List<TermsAgreementItem> terms;
  final Set<String> agreedCodes;

  const _TermsListData({required this.terms, required this.agreedCodes});

  const _TermsListData.empty()
    : terms = const <TermsAgreementItem>[],
      agreedCodes = const <String>{};
}

class _TermsMenuRow extends StatefulWidget {
  final TermsAgreementItem term;
  final bool agreed;
  final bool isSaving;
  final bool showDivider;
  final VoidCallback onTap;
  final ValueChanged<bool>? onAgreementChanged;

  const _TermsMenuRow({
    required this.term,
    required this.agreed,
    required this.isSaving,
    required this.showDivider,
    required this.onTap,
    required this.onAgreementChanged,
  });

  @override
  State<_TermsMenuRow> createState() => _TermsMenuRowState();
}

class _TermsMenuRowState extends State<_TermsMenuRow> {
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
          onTap: widget.onTap,
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
                  padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                  child: Row(
                    children: [
                      _TermRequirementBadge(required: widget.term.required),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                widget.term.required
                                    ? '버전 ${widget.term.version}'
                                    : '${widget.agreed ? '동의함' : '미동의'} · 버전 ${widget.term.version}',
                                key: ValueKey(
                                  '${widget.term.code}_${widget.agreed}',
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
                      if (!widget.term.required)
                        Switch(
                          key: ValueKey(
                            'optionalTermsSwitch_${widget.term.code}',
                          ),
                          value: widget.agreed,
                          onChanged: widget.isSaving
                              ? null
                              : widget.onAgreementChanged,
                          activeThumbColor: AppColors.ink,
                        ),
                    ],
                  ),
                ),
                if (widget.showDivider)
                  const Padding(
                    padding: EdgeInsets.only(left: 56),
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

class _TermsListErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _TermsListErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '약관을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.danger, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

void showTermsDetailSheet({
  required BuildContext context,
  required TermsAgreementItem term,
}) {
  showAppBottomSheet<void>(
    context: context,
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppSheetHandle(),
                const SizedBox(height: 18),
                Text(
                  term.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${term.required ? '필수' : '선택'} · 버전 ${term.version}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF767676),
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      term.summary,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppButtonStyles.primary(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
