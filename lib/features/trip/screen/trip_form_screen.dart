import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../service/trip_service.dart';

class TripFormScreen extends StatefulWidget {
  final TripService? tripService;
  final TripDetail? initialTrip;

  const TripFormScreen({super.key, this.tripService, this.initialTrip});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  late final TripService _tripService;
  late final TextEditingController _titleController;
  late final TextEditingController _currencyController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _countryNameController;
  late final TextEditingController _companionsController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEdit => widget.initialTrip != null;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    final trip = widget.initialTrip;
    _titleController = TextEditingController(text: trip?.title ?? '');
    _currencyController = TextEditingController(
      text: trip?.defaultCurrency ?? 'KRW',
    );
    _startDateController = TextEditingController(text: trip?.startDate ?? '');
    _endDateController = TextEditingController(text: trip?.endDate ?? '');
    final firstCountry = trip?.countries.isEmpty == false
        ? trip!.countries.first
        : null;
    _countryCodeController = TextEditingController(
      text: firstCountry?.countryCode ?? '',
    );
    _countryNameController = TextEditingController(
      text: firstCountry?.countryName ?? '',
    );
    _companionsController = TextEditingController(
      text: trip?.participants
              .where((participant) => participant.participantRole != 'LEADER')
              .map((participant) => participant.displayName)
              .join(', ') ??
          '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _currencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _countryCodeController.dispose();
    _countryNameController.dispose();
    _companionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final input = _buildInput();
    if (input == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = _isEdit
          ? await _tripService.updateTrip(widget.initialTrip!.id, input)
          : await _tripService.createTrip(input);

      if (_isEdit) {
        await _tripService.updateTripCountries(
          widget.initialTrip!.id,
          input.countries,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TripFormInput? _buildInput() {
    final title = _titleController.text.trim();
    final currency = _currencyController.text.trim().toUpperCase();
    final countryCode = _countryCodeController.text.trim().toUpperCase();
    final countryName = _countryNameController.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = '여행명을 입력해 주세요.');
      return null;
    }
    if (currency.length != 3) {
      setState(() => _errorMessage = '기본 통화는 KRW처럼 3글자로 입력해 주세요.');
      return null;
    }
    if (countryCode.isNotEmpty && countryCode.length != 2) {
      setState(() => _errorMessage = '국가 코드는 JP처럼 2글자로 입력해 주세요.');
      return null;
    }

    final countries = <TripCountryInput>[];
    if (countryCode.isNotEmpty && countryName.isNotEmpty) {
      countries.add(
        TripCountryInput(
          countryCode: countryCode,
          countryName: countryName,
          sortOrder: 0,
        ),
      );
    }

    final companions = _companionsController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => TripCompanionInput(displayName: name, profileImageUrl: null))
        .toList();

    return TripFormInput(
      title: title,
      defaultCurrency: currency,
      exchangeRateBaseDate: null,
      startDate: _nullableText(_startDateController),
      endDate: _nullableText(_endDateController),
      countries: countries,
      participants: _isEdit ? const [] : companions,
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? '여행 수정' : '여행 만들기'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _TextField(
              key: const ValueKey('tripTitleField'),
              controller: _titleController,
              label: '여행명',
              hintText: '오사카 맛집 여행',
            ),
            _TextField(
              key: const ValueKey('tripCurrencyField'),
              controller: _currencyController,
              label: '기본 통화',
              hintText: 'KRW',
              textCapitalization: TextCapitalization.characters,
            ),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    key: const ValueKey('tripStartDateField'),
                    controller: _startDateController,
                    label: '시작일',
                    hintText: '2026-07-01',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TextField(
                    key: const ValueKey('tripEndDateField'),
                    controller: _endDateController,
                    label: '종료일',
                    hintText: '2026-07-05',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: _TextField(
                    key: const ValueKey('tripCountryCodeField'),
                    controller: _countryCodeController,
                    label: '국가 코드',
                    hintText: 'JP',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TextField(
                    key: const ValueKey('tripCountryNameField'),
                    controller: _countryNameController,
                    label: '국가명',
                    hintText: '일본',
                  ),
                ),
              ],
            ),
            if (!_isEdit)
              _TextField(
                key: const ValueKey('tripCompanionsField'),
                controller: _companionsController,
                label: '동행자',
                hintText: '민수, 지현',
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('saveTripButton'),
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_isSaving ? '저장 중...' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextCapitalization textCapitalization;

  const _TextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFC7C7C7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
