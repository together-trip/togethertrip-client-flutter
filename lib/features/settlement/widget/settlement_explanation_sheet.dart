import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

class SettlementExplanationSheet extends StatelessWidget {
  const SettlementExplanationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('정산은 어떻게 계산되나요?', style: AppTextStyles.sectionTitle),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Paragraph(
                      '투게더트립은 내가 낸 돈과 내가 부담해야 할 돈을 비교해서 정산해요.\n\n많이 낸 사람은 돈을 받고, 덜 낸 사람은 돈을 보내요.',
                    ),
                    _SectionTitle('꼭 똑같이 나누는 건 아니에요'),
                    _Paragraph(
                      '지출은 항상 n분의 1로 나누지 않아도 돼요.\n\n같이 쓴 사람만 나눌 수도 있고, 사람마다 다른 금액을 부담할 수도 있어요.\n\n예를 들어 4명이 여행을 갔어도 2명만 카페에 갔다면 카페 비용은 그 2명만 나눠요.',
                    ),
                    _SectionTitle('해외 지출은 환율로 계산해요'),
                    _Paragraph(
                      '엔화, 달러처럼 원화가 아닌 돈으로 쓴 지출은 앱에 저장된 환율로 원화로 바꿔 계산해요.\n\n예를 들어 3,000엔을 썼고 1엔이 9원이라면 정산 금액은 27,000원으로 계산돼요.',
                    ),
                    _SectionTitle('왜 지금 환율이랑 다를 수 있나요?'),
                    _Paragraph(
                      '환율은 계속 바뀌어요.\n\n그래서 투게더트립은 지출을 등록할 때의 환율을 저장해요.\n\n나중에 환율이 바뀌어도 이미 등록한 지출의 정산 금액이 갑자기 바뀌지 않게 하기 위해서예요.',
                    ),
                    _SectionTitle('카드 청구 금액과 다를 수도 있어요'),
                    _Paragraph(
                      '해외 카드 결제는 카드사 수수료나 실제 청구 시점 환율 때문에 앱에서 계산한 금액과 조금 다를 수 있어요.\n\n정확한 금액으로 맞추고 싶다면 지출 금액이나 환율을 수정해 주세요.',
                    ),
                    _SectionTitle('금액 설명'),
                    _Paragraph(
                      '결제한 금액: 내가 먼저 낸 돈이에요.\n\n소비한 금액: 내가 실제로 부담해야 하는 내 몫이에요.\n\n받을 돈: 내가 더 많이 내서 받아야 하는 돈이에요.\n\n보낼 돈: 내가 덜 내서 보내야 하는 돈이에요.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: AppButtonStyles.elevatedPrimary(),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Color(0xFF4A4A4A),
      ),
    );
  }
}
