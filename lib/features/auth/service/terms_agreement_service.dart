class TermsAgreementService {
  const TermsAgreementService();

  Future<List<TermsAgreementItem>> getTerms() => getRequiredTerms();

  Future<List<TermsAgreementItem>> getRequiredTerms() async {
    return const [
      TermsAgreementItem(
        code: 'SERVICE_TERMS',
        title: '서비스 이용약관',
        version: '2026-06-17',
        required: true,
        summary: 'TogetherTrip 서비스 이용을 위한 기본 약관입니다.',
      ),
      TermsAgreementItem(
        code: 'PRIVACY_POLICY',
        title: '개인정보 처리방침',
        version: '2026-06-17',
        required: true,
        summary: '회원 식별, 프로필, 여행방 이용에 필요한 개인정보 처리 기준입니다.',
      ),
    ];
  }

  Future<void> saveAgreements({
    required List<TermsAgreementItem> agreedTerms,
  }) async {
    // TODO: Replace with backend API after togethertrip-server-main#74 is ready.
    if (agreedTerms.isEmpty) {
      throw StateError('필수 약관에 동의해주세요.');
    }
  }
}

class TermsAgreementItem {
  final String code;
  final String title;
  final String version;
  final bool required;
  final String summary;

  const TermsAgreementItem({
    required this.code,
    required this.title,
    required this.version,
    required this.required,
    required this.summary,
  });
}
