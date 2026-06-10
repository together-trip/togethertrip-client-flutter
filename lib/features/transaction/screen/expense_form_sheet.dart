import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../post/service/post_service.dart';
import '../../post/widget/attachment_input_section.dart';
import '../../trip/service/trip_service.dart';
import '../service/transaction_service.dart';

class ExpenseFormSheet extends StatefulWidget {
  final TripDetail trip;
  final int? currentParticipantId;
  final Future<void> Function({
    required TransactionFormInput transactionInput,
    required PostFormInput postInput,
  })
  onSubmit;

  const ExpenseFormSheet({
    super.key,
    required this.trip,
    required this.currentParticipantId,
    required this.onSubmit,
  });

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  static const _categories = ['관광', '식비', '교통', '숙박', '쇼핑', '기타'];

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _placeController = TextEditingController();
  final _otherCategoryController = TextEditingController();
  final Map<int, TextEditingController> _paymentControllers = {};
  final Map<int, TextEditingController> _shareControllers = {};
  final List<AttachmentDraft> _attachments = [];

  late final List<TripParticipant> _participants;
  late String _currency;
  late DateTime _selectedDate;
  String _selectedCategory = '식비';
  bool _isSubmitting = false;
  String? _errorMessage;

  int? get _amountCents => _parseAmountCents(_amountController.text);

  int get _paymentTotalCents => _sumControllerCents(_paymentControllers);

  int get _shareTotalCents => _sumControllerCents(_shareControllers);

  @override
  void initState() {
    super.initState();
    _participants = widget.trip.participants
        .where((participant) => participant.participantStatus == 'ACTIVE')
        .toList();
    _currency = widget.trip.defaultCurrency;
    _selectedDate = DateTime.now();
    for (final participant in _participants) {
      _paymentControllers[participant.id] = TextEditingController(text: '0');
      _shareControllers[participant.id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _placeController.dispose();
    _otherCategoryController.dispose();
    for (final controller in _paymentControllers.values) {
      controller.dispose();
    }
    for (final controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _splitEvenly() {
    final cents = _amountCents;
    if (cents == null || cents <= 0 || _participants.isEmpty) return;

    final base = cents ~/ _participants.length;
    var remainder = cents % _participants.length;
    for (final participant in _participants) {
      var participantCents = base;
      if (remainder > 0) {
        participantCents += 1;
        remainder -= 1;
      }
      _shareControllers[participant.id]?.text = _formatCents(participantCents);
    }
    setState(() {});
  }

  void _fillPaymentByDefaultPayer() {
    final cents = _amountCents;
    if (cents == null || cents <= 0 || _participants.isEmpty) return;

    final defaultPayerId =
        widget.currentParticipantId ??
        (_participants.isNotEmpty ? _participants.first.id : null);
    for (final participant in _participants) {
      _paymentControllers[participant.id]?.text =
          participant.id == defaultPayerId ? _formatCents(cents) : '0';
    }
    setState(() {});
  }

  void _syncAmountDefaults() {
    _fillPaymentByDefaultPayer();
    _splitEvenly();
  }

  Future<void> _submit() async {
    final amountCents = _amountCents;
    final title = _titleController.text.trim();
    final category = _selectedCategory == '기타'
        ? _otherCategoryController.text.trim()
        : _selectedCategory;

    if (amountCents == null || amountCents <= 0) {
      setState(() => _errorMessage = '금액을 입력해주세요.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = '제목을 입력해주세요.');
      return;
    }
    if (category.isEmpty) {
      setState(() => _errorMessage = '기타 카테고리를 입력해주세요.');
      return;
    }

    final payments = <TransactionPaymentInput>[];
    var paymentTotalCents = 0;
    for (final participant in _participants) {
      final paymentCents = _parseAmountCents(
        _paymentControllers[participant.id]?.text ?? '',
      );
      if (paymentCents == null || paymentCents <= 0) continue;
      paymentTotalCents += paymentCents;
      payments.add(
        TransactionPaymentInput(
          participantId: participant.id,
          amount: _centsToAmount(paymentCents),
        ),
      );
    }

    final shares = <TransactionShareInput>[];
    var shareTotalCents = 0;
    for (final participant in _participants) {
      final shareCents = _parseAmountCents(
        _shareControllers[participant.id]?.text ?? '',
      );
      if (shareCents == null || shareCents <= 0) continue;
      shareTotalCents += shareCents;
      shares.add(
        TransactionShareInput(
          participantId: participant.id,
          shareAmount: _centsToAmount(shareCents),
          shareRatio: amountCents == 0 ? 0 : shareCents / amountCents,
        ),
      );
    }

    if (payments.isEmpty) {
      setState(() => _errorMessage = '결제자를 입력해주세요.');
      return;
    }
    if (paymentTotalCents != amountCents) {
      setState(() => _errorMessage = '결제 금액 합계가 총 금액과 같아야 합니다.');
      return;
    }
    if (shares.isEmpty) {
      setState(() => _errorMessage = '부담자를 선택해주세요.');
      return;
    }
    if (shareTotalCents != amountCents) {
      setState(() => _errorMessage = '부담 금액 합계가 총 금액과 같아야 합니다.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        transactionInput: TransactionFormInput(
          transactionType: 'EXPENSE',
          amount: _centsToAmount(amountCents),
          currency: _currency,
          payments: payments,
          shares: shares,
        ),
        postInput: PostFormInput(
          transactionId: null,
          title: title,
          category: category,
          content: _nullableText(_contentController.text),
          postType: 'EXPENSE',
          occurredAt: _toOccurredAt(_selectedDate),
          placeName: _nullableText(_placeController.text),
          latitude: null,
          longitude: null,
          files: buildAttachmentInputs(_attachments),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  const Expanded(
                    child: Text(
                      '소비 등록',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting || _participants.isEmpty
                        ? null
                        : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('등록'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [_MoneyInputFormatter()],
                      onChanged: (_) => _syncAmountDefaults(),
                      decoration: const InputDecoration(
                        labelText: '금액',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      items: _currencyOptions
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _currency = value);
                            },
                      decoration: const InputDecoration(
                        labelText: '통화',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '결제자',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : _fillPaymentByDefaultPayer,
                    child: const Text('전액 입력'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._participants.map((participant) {
                return _ParticipantAmountRow(
                  participant: participant,
                  controller: _paymentControllers[participant.id]!,
                  enabled: !_isSubmitting,
                  onChanged: () => setState(() {}),
                );
              }),
              _AmountTotalRow(
                label: '결제 합계',
                amountCents: _paymentTotalCents,
                expectedCents: _amountCents,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '부담자',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _splitEvenly,
                    child: const Text('균등 분배'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._participants.map((participant) {
                return _ParticipantAmountRow(
                  participant: participant,
                  controller: _shareControllers[participant.id]!,
                  enabled: !_isSubmitting,
                  onChanged: () => setState(() {}),
                );
              }),
              _AmountTotalRow(
                label: '부담 합계',
                amountCents: _shareTotalCents,
                expectedCents: _amountCents,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
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
                        selectedColor: const Color(0xFF1A1A1A),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
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
                  decoration: const InputDecoration(
                    labelText: '기타 카테고리',
                    border: OutlineInputBorder(),
                  ),
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
                decoration: const InputDecoration(
                  labelText: '장소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contentController,
                enabled: !_isSubmitting,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '내용',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              AttachmentInputSection(
                attachments: _attachments,
                enabled: !_isSubmitting,
                onChanged: (_) => setState(() {}),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFCC0000),
                    fontSize: 12,
                  ),
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

class _ParticipantAmountRow extends StatelessWidget {
  final TripParticipant participant;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  const _ParticipantAmountRow({
    required this.participant,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _ParticipantAvatar(participant: participant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              participant.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_MoneyInputFormatter()],
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountTotalRow extends StatelessWidget {
  final String label;
  final int amountCents;
  final int? expectedCents;

  const _AmountTotalRow({
    required this.label,
    required this.amountCents,
    required this.expectedCents,
  });

  @override
  Widget build(BuildContext context) {
    final expected = expectedCents;
    final matched = expected != null && expected > 0 && amountCents == expected;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Spacer(),
          Text(
            '$label ${_formatCents(amountCents)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: matched
                  ? const Color(0xFF1A7F37)
                  : const Color(0xFF6B6B6B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final TripParticipant participant;

  const _ParticipantAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = participant.profileImageUrl;
    final hasProfile =
        participant.userId != null &&
        profileImageUrl != null &&
        profileImageUrl.isNotEmpty;

    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFF2F2F2),
      backgroundImage: hasProfile ? NetworkImage(profileImageUrl) : null,
      child: hasProfile
          ? null
          : const Icon(
              Icons.person_outline,
              size: 20,
              color: Color(0xFF8A8A8A),
            ),
    );
  }
}

const _currencyOptions = ['KRW', 'JPY', 'USD', 'EUR', 'CNY', 'TWD', 'HKD'];

String? _nullableText(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseAmountCents(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty) return null;
  final match = RegExp(r'^\d+(\.\d{0,2})?$').firstMatch(normalized);
  if (match == null) return null;

  final parts = normalized.split('.');
  final major = int.tryParse(parts.first);
  if (major == null) return null;
  final minorText = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final minor = int.tryParse(minorText);
  if (minor == null) return null;
  return major * 100 + minor;
}

int _sumControllerCents(Map<int, TextEditingController> controllers) {
  var total = 0;
  for (final controller in controllers.values) {
    total += _parseAmountCents(controller.text) ?? 0;
  }
  return total;
}

double _centsToAmount(int cents) {
  return cents / 100;
}

String _formatCents(int cents) {
  final major = cents ~/ 100;
  final minor = cents.abs() % 100;
  final majorText = _formatThousands(major.toString());
  if (minor == 0) return majorText;
  return '$majorText.${minor.toString().padLeft(2, '0')}';
}

String _formatThousands(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(value[i]);
  }
  return buffer.toString();
}

class _MoneyInputFormatter extends TextInputFormatter {
  const _MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final integerPart = parts.first.isEmpty ? '0' : parts.first;
    final formattedInteger = _formatThousands(
      integerPart.replaceFirst(RegExp(r'^0+(?=\d)'), ''),
    );
    final formatted = parts.length > 1
        ? '$formattedInteger.${parts[1]}'
        : formattedInteger;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
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
