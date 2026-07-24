import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class MyProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final bool isLoading;
  final VoidCallback? onTap;

  const MyProfileHeader({
    super.key,
    required this.profile,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = profile?.nickname;
    final profileImageUrl = profile?.profileImageUrl;
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;

    return GestureDetector(
      onTap: isLoading || profile == null ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: hasProfileImage
                    ? Image.network(
                        resolveApiUrl(profileImageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _ProfileFallback(nickname: nickname),
                      )
                    : _ProfileFallback(nickname: nickname),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '불러오는 중...' : (nickname ?? '닉네임 없음'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '내 프로필 보기 및 수정',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  final String? nickname;

  const _ProfileFallback({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandSoft,
      ),
      child: Center(
        child: Text(
          (nickname != null && nickname!.isNotEmpty)
              ? nickname!.substring(0, 1)
              : '나',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.brandStrong,
          ),
        ),
      ),
    );
  }
}
