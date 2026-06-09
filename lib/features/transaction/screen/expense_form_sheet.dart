import 'package:flutter/material.dart';

import '../../post/service/post_service.dart';
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
  final Map<int, TextEditingController> _shareControllers = {};

  late final List<TripParticipant> _participants;
  late String _currency;
  late DateTime _selectedDate;
  int? _payerParticipantId;
  String _selectedCategory = '식비';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _participants = widget.trip.participants
        .where((participant) => participant.participantStatus == 'ACTIVE')
        .toList();
    _currency = widget.trip.defaultCurrency;
    _selectedDate = DateTime.now();
    _payerParticipantId =
        widget.currentParticipantId ??
        (_participants.isNotEmpty ? _participants.first.id : null);
    for (final participant in _participants) {
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
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0 || _participants.isEmpty) return;

    final cents = (amount * 100).round();
    final base = cents ~/ _participants.length;
    var remainder = cents % _participants.length;
    for (final participant in _participants) {
      var participantCents = base;
      if (remainder > 0) {
        participantCents += 1;
        remainder -= 1;
      }
      _shareControllers[participant.id]?.text = _formatDecimal(
        participantCents / 100,
      );
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final amount = _parseAmount(_amountController.text);
    final title = _titleController.text.trim();
    final category = _selectedCategory == '기타'
        ? _otherCategoryController.text.trim()
        : _selectedCategory;
    final payerParticipantId = _payerParticipantId;

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = '금액을 입력해주세요.');
      return;
    }
    if (payerParticipantId == null) {
      setState(() => _errorMessage = '결제자를 선택해주세요.');
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

    final shares = <TransactionShareInput>[];
    var shareTotal = 0.0;
    for (final participant in _participants) {
      final shareAmount = _parseAmount(
        _shareControllers[participant.id]?.text ?? '',
      );
      if (shareAmount == null || shareAmount <= 0) continue;
      shareTotal += shareAmount;
      shares.add(
        TransactionShareInput(
          participantId: participant.id,
          shareAmount: shareAmount,
          shareRatio: amount == 0 ? 0 : shareAmount / amount,
        ),
      );
    }

    if (shares.isEmpty) {
      setState(() => _errorMessage = '부담자를 선택해주세요.');
      return;
    }
    if (((shareTotal - amount) * 100).round() != 0) {
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
          amount: amount,
          currency: _currency,
          payments: [
            TransactionPaymentInput(
              participantId: payerParticipantId,
              amount: amount,
            ),
          ],
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
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.94,
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
              const Text(
                '소비 등록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      onChanged: (_) => _splitEvenly(),
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
              DropdownButtonFormField<int>(
                initialValue: _payerParticipantId,
                items: _participants
                    .map(
                      (participant) => DropdownMenuItem(
                        value: participant.id,
                        child: Text(participant.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _payerParticipantId = value),
                decoration: const InputDecoration(
                  labelText: '결제자',
                  border: OutlineInputBorder(),
                ),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          participant.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 132,
                        child: TextField(
                          controller: _shareControllers[participant.id],
                          enabled: !_isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
              }),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: _isSubmitting
                        ? null
                        : (_) => setState(() => _selectedCategory = category),
                  );
                }).toList(),
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
              FilledButton(
                onPressed: _isSubmitting || _participants.isEmpty
                    ? null
                    : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('등록하기'),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _currencyOptions = ['KRW', 'JPY', 'USD', 'EUR', 'CNY', 'TWD', 'HKD'];

String? _nullableText(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _parseAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _formatDecimal(double value) {
  if (value.truncateToDouble() == value) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
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
