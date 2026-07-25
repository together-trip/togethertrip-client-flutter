import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/moderation/service/content_warning_detector.dart';

void main() {
  const detector = ContentWarningDetector();

  test('명시적 욕설과 숫자·공백을 섞은 변형을 감지한다', () {
    expect(
      detector.containsPotentiallyOffensiveContent(['씨1 발', '여행']),
      isTrue,
    );
    expect(detector.containsPotentiallyOffensiveContent(['ㅅ-ㅂ']), isTrue);
    expect(detector.containsPotentiallyOffensiveContent(['개 새 끼야']), isTrue);
  });

  test('정상 여행 문장과 욕설 일부가 포함된 일반 단어는 감지하지 않는다', () {
    expect(
      detector.containsPotentiallyOffensiveContent(['시발점에서 다시 출발해요']),
      isFalse,
    );
    expect(
      detector.containsPotentiallyOffensiveContent(['새끼손가락을 다쳤어요']),
      isFalse,
    );
    expect(
      detector.containsPotentiallyOffensiveContent(['오사카 여행이 즐거웠어요']),
      isFalse,
    );
  });

  test('null과 빈 입력만 전달하면 감지하지 않는다', () {
    expect(
      detector.containsPotentiallyOffensiveContent([null, '', '   ']),
      isFalse,
    );
  });
}
