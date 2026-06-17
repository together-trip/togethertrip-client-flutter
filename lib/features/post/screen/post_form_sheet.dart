import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';

import '../../../core/widget/app_date_picker.dart';
import '../service/post_service.dart';
import '../widget/attachment_input_section.dart';

class PostFormSheet extends StatefulWidget {
  final String postType;
  final PostDetail? initialPost;
  final Future<void> Function(PostFormInput input) onSubmit;

  const PostFormSheet({
    super.key,
    required this.postType,
    required this.onSubmit,
    this.initialPost,
  });

  @override
  State<PostFormSheet> createState() => _PostFormSheetState();
}

class _PostFormSheetState extends State<PostFormSheet> {
  static const _categories = ['관광', '식비', '교통', '숙박', '쇼핑', '기타'];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _placeController = TextEditingController();
  final _otherCategoryController = TextEditingController();
  final List<AttachmentDraft> _attachments = [];
  final List<PostAttachment> _existingAttachments = [];

  String _selectedCategory = _categories.first;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _attachmentsChanged = false;

  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    final initialPost = widget.initialPost;
    if (initialPost == null) return;

    _titleController.text = initialPost.title;
    _contentController.text = initialPost.content ?? '';
    _placeController.text = initialPost.placeName ?? '';
    if (_categories.contains(initialPost.category)) {
      _selectedCategory = initialPost.category;
    } else {
      _selectedCategory = '기타';
      _otherCategoryController.text = initialPost.category;
    }
    _selectedDate = _parseDate(initialPost.occurredAt) ?? DateTime.now();
    _existingAttachments.addAll(initialPost.attachments);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _placeController.dispose();
    _otherCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showTogetherTripDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '기록 날짜',
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final category = _selectedCategory == '기타'
        ? _otherCategoryController.text.trim()
        : _selectedCategory;
    if (title.isEmpty) {
      setState(() => _errorMessage = '제목을 입력해주세요.');
      return;
    }
    if (category.isEmpty) {
      setState(() => _errorMessage = '기타 카테고리를 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        PostFormInput(
          transactionId: widget.initialPost?.transactionId,
          title: title,
          category: category,
          content: _nullableText(_contentController.text),
          postType: widget.initialPost?.postType ?? widget.postType,
          occurredAt: _toOccurredAt(_selectedDate),
          placeName: _nullableText(_placeController.text),
          latitude: null,
          longitude: null,
          files: buildAttachmentInputs(_attachments),
          replaceAttachments: _attachmentsChanged,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  Expanded(
                    child: Text(
                      _isEditing ? '기록 수정' : '기록 작성',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? '저장' : '등록'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                enabled: !_isSubmitting,
                decoration: AppInputDecorations.filled(labelText: '제목'),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final selected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        selectedColor: AppColors.ink,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: _isSubmitting
                            ? null
                            : (_) =>
                                  setState(() => _selectedCategory = category),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedCategory == '기타') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherCategoryController,
                  enabled: !_isSubmitting,
                  decoration: AppInputDecorations.filled(labelText: '기타 카테고리'),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_dateLabel(_selectedDate)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _placeController,
                enabled: !_isSubmitting,
                decoration: AppInputDecorations.filled(labelText: '장소'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contentController,
                enabled: !_isSubmitting,
                minLines: 6,
                maxLines: 10,
                decoration: AppInputDecorations.filled(
                  labelText: '내용',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              AttachmentInputSection(
                attachments: _attachments,
                existingAttachments: _attachmentsChanged
                    ? const []
                    : _existingAttachments,
                enabled: !_isSubmitting,
                onChanged: (changed) {
                  setState(() => _attachmentsChanged = changed);
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

String? _nullableText(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String _toOccurredAt(DateTime date) {
  final kstNoon = DateTime(date.year, date.month, date.day, 12);
  return kstNoon.toUtc().toIso8601String();
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
