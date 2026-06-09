import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../service/post_service.dart';

const maxPostAttachmentCount = 10;

class AttachmentDraft {
  final String path;
  final String filename;
  final String? mimeType;

  const AttachmentDraft({
    required this.path,
    required this.filename,
    required this.mimeType,
  });

  factory AttachmentDraft.fromXFile(XFile file) {
    return AttachmentDraft(
      path: file.path,
      filename: file.name,
      mimeType: file.mimeType ?? _inferImageMimeType(file.name),
    );
  }

  PostFileInput toInput() {
    return PostFileInput(path: path, filename: filename, mimeType: mimeType);
  }
}

class AttachmentInputSection extends StatefulWidget {
  final List<AttachmentDraft> attachments;
  final List<PostAttachment> existingAttachments;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const AttachmentInputSection({
    super.key,
    required this.attachments,
    this.existingAttachments = const [],
    required this.enabled,
    this.onChanged,
  });

  @override
  State<AttachmentInputSection> createState() => _AttachmentInputSectionState();
}

class _AttachmentInputSectionState extends State<AttachmentInputSection> {
  final _picker = ImagePicker();

  Future<void> _pickImages() async {
    final remaining =
        maxPostAttachmentCount -
        widget.existingAttachments.length -
        widget.attachments.length;
    if (!widget.enabled || remaining <= 0) return;

    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final nextFiles = picked
        .take(remaining)
        .map(AttachmentDraft.fromXFile)
        .toList();
    setState(() => widget.attachments.addAll(nextFiles));
    widget.onChanged?.call(true);
  }

  void _removeNewAttachment(int index) {
    setState(() => widget.attachments.removeAt(index));
    widget.onChanged?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    final totalCount =
        widget.existingAttachments.length + widget.attachments.length;
    final canAdd = widget.enabled && totalCount < maxPostAttachmentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '첨부파일 $totalCount/$maxPostAttachmentCount',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: canAdd ? _pickImages : null,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalCount == 0)
          OutlinedButton.icon(
            onPressed: widget.enabled ? _pickImages : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: const Text('사진 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: totalCount,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index < widget.existingAttachments.length) {
                  return _ExistingAttachmentPreview(
                    attachment: widget.existingAttachments[index],
                  );
                }

                final newIndex = index - widget.existingAttachments.length;
                return _NewAttachmentPreview(
                  attachment: widget.attachments[newIndex],
                  enabled: widget.enabled,
                  onRemove: () => _removeNewAttachment(newIndex),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ExistingAttachmentPreview extends StatelessWidget {
  final PostAttachment attachment;

  const _ExistingAttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final rawImageUrl = attachment.thumbnailUrl?.isNotEmpty == true
        ? attachment.thumbnailUrl!
        : attachment.fileUrl;
    final imageUrl = resolveApiUrl(rawImageUrl);

    return _AttachmentFrame(
      child: attachment.attachmentType == 'VIDEO'
          ? const Icon(Icons.play_circle_outline, size: 34)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported_outlined);
              },
            ),
    );
  }
}

class _NewAttachmentPreview extends StatelessWidget {
  final AttachmentDraft attachment;
  final bool enabled;
  final VoidCallback onRemove;

  const _NewAttachmentPreview({
    required this.attachment,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _AttachmentFrame(
          child: Image.file(File(attachment.path), fit: BoxFit.cover),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: IconButton.filled(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close, size: 16),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentFrame extends StatelessWidget {
  final Widget child;

  const _AttachmentFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF5F5F5),
        ),
        child: SizedBox(width: 112, height: 112, child: child),
      ),
    );
  }
}

List<PostFileInput> buildAttachmentInputs(List<AttachmentDraft> attachments) {
  return attachments.map((attachment) => attachment.toInput()).toList();
}

String _inferImageMimeType(String filename) {
  final normalized = filename.toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
