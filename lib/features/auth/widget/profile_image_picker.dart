import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../../../core/network/api_client.dart';
import '../service/auth_service.dart';

class ProfileImagePicker extends StatelessWidget {
  final String nickname;
  final String? currentImageUrl;
  final ProfileImageInput? selectedImage;
  final VoidCallback onPick;

  const ProfileImagePicker({
    super.key,
    required this.nickname,
    required this.currentImageUrl,
    required this.selectedImage,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final selectedImage = this.selectedImage;
    final currentImageUrl = this.currentImageUrl;
    final hasCurrentImage =
        currentImageUrl != null && currentImageUrl.isNotEmpty;
    final buttonLabel = selectedImage != null
        ? '다시 선택'
        : hasCurrentImage
        ? '이미지 변경'
        : '이미지 선택';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: SizedBox(
            width: 72,
            height: 72,
            child: selectedImage != null
                ? Image.file(File(selectedImage.path), fit: BoxFit.cover)
                : hasCurrentImage
                ? Image.network(
                    resolveApiUrl(currentImageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ProfileImageFallback(nickname: nickname),
                  )
                : ProfileImageFallback(nickname: nickname),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('pickProfileImageButton'),
          onPressed: onPick,
          icon: const Icon(Icons.photo_camera_outlined, size: 17),
          label: Text(buttonLabel),
          style: AppButtonStyles.inkText(),
        ),
      ],
    );
  }
}

class ProfileImageFallback extends StatelessWidget {
  final String nickname;

  const ProfileImageFallback({super.key, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : '나';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.brandStrong,
          ),
        ),
      ),
    );
  }
}
