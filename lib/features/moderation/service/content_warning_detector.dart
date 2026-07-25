class ContentWarningDetector {
  const ContentWarningDetector();

  bool containsPotentiallyOffensiveContent(Iterable<String?> values) {
    final content = values.whereType<String>().join(' ');
    return _patterns.any((pattern) => pattern.hasMatch(content));
  }

  // CC0-1.0 KoreanCursewordRegex의 패턴을 참고하되 오탐이 큰 정치·일상 표현은 제외했다.
  // Source: https://github.com/curioustorvald/KoreanCursewordRegex (cc15736)
  static final List<RegExp> _patterns = [
    RegExp(
      r'(?:씨|시|씹|쒸)[\s0-9._-]*(?:발|벌|팔|빨)(?:아|놈|년)?(?![가-힣])',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(
      r'[ㅅㅆ][\s0-9._-]*ㅂ(?![ㄱ-ㅎㅏ-ㅣ가-힣])',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(
      r'[병븅][\s0-9._-]*신(?:아|놈|년)?(?![가-힣])',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(r'[좆좇졷좄좃좉졽]', caseSensitive: false, unicode: true),
    RegExp(
      r'(?:개[\s0-9._-]*)?새[\s0-9._-]*끼(?:야|놈|년)?(?![가-힣])',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(r'[지쥐][\s0-9._-]*랄(?:하|이|아)?', caseSensitive: false, unicode: true),
    RegExp(
      r'니[\s0-9._-]*[애에][\s0-9._-]*미',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(r'[존좉좇][\s0-9._-]*나', caseSensitive: false, unicode: true),
  ];
}
