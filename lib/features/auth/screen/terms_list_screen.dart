import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../service/terms_agreement_service.dart';

class TermsListScreen extends StatefulWidget {
  final TermsAgreementService termsAgreementService;

  const TermsListScreen({
    super.key,
    TermsAgreementService? termsAgreementService,
  }) : termsAgreementService =
           termsAgreementService ?? const TermsAgreementService();

  @override
  State<TermsListScreen> createState() => _TermsListScreenState();
}

class _TermsListScreenState extends State<TermsListScreen> {
  late Future<List<TermsAgreementItem>> _termsFuture;

  @override
  void initState() {
    super.initState();
    _termsFuture = widget.termsAgreementService.getTerms();
  }

  void _showTermsDetail(TermsAgreementItem term) {
    showTermsDetailSheet(context: context, term: term);
  }

  void _retry() {
    setState(() => _termsFuture = widget.termsAgreementService.getTerms());
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
      body: FutureBuilder<List<TermsAgreementItem>>(
        future: _termsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _TermsListErrorState(onRetry: _retry);
          }

          final terms = snapshot.data ?? const <TermsAgreementItem>[];
          return ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              for (final term in terms)
                _TermsMenuRow(term: term, onTap: () => _showTermsDetail(term)),
            ],
          );
        },
      ),
    );
  }
}

class _TermsMenuRow extends StatelessWidget {
  final TermsAgreementItem term;
  final VoidCallback onTap;

  const _TermsMenuRow({required this.term, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Icon(Icons.article_outlined, size: 20, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    term.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${term.required ? '필수' : '선택'} · 버전 ${term.version}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF9E9E9E)),
          ],
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF767676)),
              ),
              const SizedBox(height: 18),
              Text(
                term.summary,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF3A3A3A),
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
      );
    },
  );
}
