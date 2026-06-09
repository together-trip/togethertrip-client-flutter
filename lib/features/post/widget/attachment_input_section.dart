import 'package:flutter/material.dart';

import '../service/post_service.dart';

class AttachmentDraft {
  String attachmentType;
  final TextEditingController fileUrlController;
  final TextEditingController thumbnailUrlController;

  AttachmentDraft({
    this.attachmentType = 'IMAGE',
    String fileUrl = '',
    String thumbnailUrl = '',
  }) : fileUrlController = TextEditingController(text: fileUrl),
       thumbnailUrlController = TextEditingController(text: thumbnailUrl);

  factory AttachmentDraft.fromAttachment(PostAttachment attachment) {
    return AttachmentDraft(
      attachmentType: attachment.attachmentType,
      fileUrl: attachment.fileUrl,
      thumbnailUrl: attachment.thumbnailUrl ?? '',
    );
  }

  PostAttachmentInput? toInput(int sortOrder) {
    final fileUrl = fileUrlController.text.trim();
    if (fileUrl.isEmpty) return null;

    return PostAttachmentInput(
      attachmentType: attachmentType,
      fileUrl: fileUrl,
      thumbnailUrl: _nullableText(thumbnailUrlController.text),
      fileSize: null,
      mimeType: _inferMimeType(attachmentType, fileUrl),
      sortOrder: sortOrder,
    );
  }

  void dispose() {
    fileUrlController.dispose();
    thumbnailUrlController.dispose();
  }
}

class AttachmentInputSection extends StatefulWidget {
  final List<AttachmentDraft> attachments;
  final bool enabled;

  const AttachmentInputSection({
    super.key,
    required this.attachments,
    required this.enabled,
  });

  @override
  State<AttachmentInputSection> createState() => _AttachmentInputSectionState();
}

class _AttachmentInputSectionState extends State<AttachmentInputSection> {
  void _addAttachment() {
    setState(() => widget.attachments.add(AttachmentDraft()));
  }

  void _removeAttachment(int index) {
    final removed = widget.attachments.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '첨부파일',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: widget.enabled ? _addAttachment : null,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (widget.attachments.isEmpty)
          const Text(
            '첨부할 이미지나 영상 URL을 추가할 수 있습니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
          )
        else
          ...List.generate(widget.attachments.length, (index) {
            final attachment = widget.attachments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 112,
                            child: DropdownButtonFormField<String>(
                              initialValue: attachment.attachmentType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'IMAGE',
                                  child: Text('이미지'),
                                ),
                                DropdownMenuItem(
                                  value: 'VIDEO',
                                  child: Text('영상'),
                                ),
                              ],
                              onChanged: widget.enabled
                                  ? (value) {
                                      if (value == null) return;
                                      setState(() {
                                        attachment.attachmentType = value;
                                      });
                                    }
                                  : null,
                              decoration: const InputDecoration(
                                labelText: '유형',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: widget.enabled
                                ? () => _removeAttachment(index)
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '첨부파일 삭제',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: attachment.fileUrlController,
                        enabled: widget.enabled,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '파일 URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: attachment.thumbnailUrlController,
                        enabled: widget.enabled,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '썸네일 URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

List<PostAttachmentInput> buildAttachmentInputs(
  List<AttachmentDraft> attachments,
) {
  final inputs = <PostAttachmentInput>[];
  for (final attachment in attachments) {
    final input = attachment.toInput(inputs.length);
    if (input != null) inputs.add(input);
  }
  return inputs;
}

String? _nullableText(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _inferMimeType(String attachmentType, String fileUrl) {
  final normalized = fileUrl.toLowerCase().split('?').first;
  if (attachmentType == 'VIDEO') {
    if (normalized.endsWith('.mp4')) return 'video/mp4';
    if (normalized.endsWith('.webm')) return 'video/webm';
    return 'video/*';
  }
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.gif')) return 'image/gif';
  return 'image/*';
}
