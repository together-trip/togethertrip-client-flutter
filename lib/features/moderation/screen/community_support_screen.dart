import 'package:flutter/material.dart';

import '../../../core/env/env.dart';
import '../../../core/widget/app_design.dart';

enum CommunitySupportPage { support, policy }

class CommunitySupportScreen extends StatelessWidget {
  const CommunitySupportScreen({super.key, required this.page});

  final CommunitySupportPage page;

  @override
  Widget build(BuildContext context) {
    final isSupport = page == CommunitySupportPage.support;
    return Scaffold(
      appBar: AppBar(title: Text(isSupport ? '고객지원' : '커뮤니티 운영정책')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: isSupport ? _supportContent() : _policyContent(),
      ),
    );
  }

  List<Widget> _supportContent() => [
    const _InfoCard(
      icon: Icons.support_agent_rounded,
      title: '도움이 필요하신가요?',
      body: '서비스 이용 중 발생한 문제나 신고 처리에 관한 문의는 아래 고객지원 이메일로 보내주세요.',
    ),
    const SizedBox(height: 16),
    if (Env.supportEmail.isNotEmpty)
      const SelectableText(Env.supportEmail, style: AppTextStyles.sectionTitle)
    else
      const Text('고객지원 연락처를 준비하고 있습니다.', style: AppTextStyles.sectionTitle),
    const SizedBox(height: 8),
    Text(
      '문의 시 계정 비밀번호나 인증 토큰은 보내지 마세요.',
      style: AppTextStyles.body.copyWith(color: AppColors.textSubtle),
    ),
  ];

  List<Widget> _policyContent() => [
    const _InfoCard(
      icon: Icons.shield_outlined,
      title: '서로를 존중해 주세요',
      body: '괴롭힘, 혐오 표현, 폭력·성적 콘텐츠, 개인정보 노출, 스팸 및 불법 콘텐츠는 허용되지 않습니다.',
    ),
    const SizedBox(height: 16),
    const _PolicySection(
      title: '신고와 검토',
      body:
          '신고된 콘텐츠는 운영 정책에 따라 검토되며, 필요한 경우 숨김·삭제 또는 사용자 이용 제한 조치가 적용될 수 있습니다.',
    ),
    const _PolicySection(
      title: '차단',
      body:
          '사용자를 차단하면 그 사용자의 일반 기록과 댓글이 숨겨집니다. 여행의 지출·정산 원장과 참여자 정보는 금액 무결성을 위해 보존됩니다.',
    ),
    const _PolicySection(
      title: '안전한 이용',
      body: '위급한 상황이나 범죄 피해가 우려될 때는 앱 신고와 별개로 관할 기관에 즉시 도움을 요청하세요.',
    ),
  ];
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brandStrong),
        const SizedBox(height: 10),
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 6),
        Text(body, style: AppTextStyles.body),
      ],
    ),
  );
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 6),
        Text(body, style: AppTextStyles.body),
      ],
    ),
  );
}
