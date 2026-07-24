import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../../../core/widget/app_date_picker.dart';
import '../../notification/screen/notification_list_screen.dart';
import '../../notification/widget/notification_badge_button.dart';
import '../model/exchange_rate_models.dart';
import '../service/exchange_rate_service.dart';

enum _ExchangePeriod { today, sevenDays, thirtyDays, custom }

class ExchangeRateScreen extends StatefulWidget {
  final ExchangeRateService? exchangeRateService;

  const ExchangeRateScreen({super.key, this.exchangeRateService});

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  late final ExchangeRateService _exchangeRateService;
  final TextEditingController _amountController = TextEditingController(
    text: '1,000.00',
  );

  ExchangeCountryOption _selectedCountry = exchangeCountryOptions.first;
  _ExchangePeriod _selectedPeriod = _ExchangePeriod.today;
  DateTimeRange? _customRange;
  ExchangeRateSearchResult? _result;
  bool _isLoading = true;
  bool _isForeignToKrw = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _exchangeRateService = widget.exchangeRateService ?? ExchangeRateService();
    _loadRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _buildDateQuery();
      final result = await _exchangeRateService.getExchangeRates(
        targetCurrencies: [_selectedCountry.currencyCode],
        date: query.date,
        from: query.from,
        to: query.to,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorMessage = '환율을 불러오지 못했습니다: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _DateQuery _buildDateQuery() {
    final today = DateTime.now();
    return switch (_selectedPeriod) {
      _ExchangePeriod.today => _DateQuery(date: _formatDate(today)),
      _ExchangePeriod.sevenDays => _DateQuery(
        from: _formatDate(today.subtract(const Duration(days: 6))),
        to: _formatDate(today),
      ),
      _ExchangePeriod.thirtyDays => _DateQuery(
        from: _formatDate(today.subtract(const Duration(days: 29))),
        to: _formatDate(today),
      ),
      _ExchangePeriod.custom => _DateQuery(
        from: _formatDate(_customRange?.start ?? today),
        to: _formatDate(_customRange?.end ?? today),
      ),
    };
  }

  Future<void> _selectPeriod(_ExchangePeriod period) async {
    if (period == _ExchangePeriod.custom) {
      final today = DateTime.now();
      final picked = await showTogetherTripDateRangePicker(
        context: context,
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: today.subtract(const Duration(days: 6)),
              end: today,
            ),
        firstDate: DateTime(2000),
        lastDate: today,
        helpText: '환율 조회 기간',
      );
      if (picked == null) return;
      setState(() {
        _selectedPeriod = period;
        _customRange = picked;
      });
      await _loadRates();
      return;
    }

    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    await _loadRates();
  }

  void _selectCountry(ExchangeCountryOption? country) {
    if (country == null ||
        country.currencyCode == _selectedCountry.currencyCode) {
      return;
    }
    setState(() => _selectedCountry = country);
    _loadRates();
  }

  List<ExchangeRateRecord> get _sortedRates {
    final rates = [...?_result?.rates];
    rates.sort((a, b) => b.rateDate.compareTo(a.rateDate));
    return rates;
  }

  ExchangeRateRecord? get _latestRate {
    final rates = _sortedRates;
    return rates.isEmpty ? null : rates.first;
  }

  double get _inputAmount {
    final normalized = _amountController.text.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  double? get _convertedAmount {
    final rate = _latestRate;
    if (rate == null) return null;
    if (_isForeignToKrw) return _inputAmount * rate.rate;
    if (rate.rate == 0) return null;
    return _inputAmount / rate.rate;
  }

  void _swapDirection() {
    final nextInput = _convertedAmount;
    setState(() {
      _isForeignToKrw = !_isForeignToKrw;
      if (nextInput != null) {
        final formatted = _formatInputAmount(nextInput);
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
  }

  void _showSettlementNotice() {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSheetHandle(),
                const SizedBox(height: 18),
                const Text(
                  '정산 환율 안내',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '정산에서는 등록된 지출 금액에 앱의 환율 기준을 적용해 계산해요. 카드사 수수료나 실제 청구 시점의 환율 때문에 카드 명세서 금액과 다를 수 있습니다.',
                  style: TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppButtonStyles.elevatedPrimary().copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNotifications() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '환율',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: [
          NotificationBadgeButton(
            buttonKey: const ValueKey('exchangeNotificationButton'),
            onPressed: _openNotifications,
          ),
          IconButton(
            key: const ValueKey('exchangeRefreshButton'),
            onPressed: _isLoading ? null : _loadRates,
            icon: const Icon(Icons.refresh, size: 22),
            color: AppColors.ink,
            tooltip: '환율 새로고침',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRates,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          children: [
            const Text('금액을 바로 환산해보세요', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _RateSummaryCard(
              country: _selectedCountry,
              latestRate: _latestRate,
              isLoading: _isLoading,
              amountController: _amountController,
              convertedAmount: _convertedAmount,
              isForeignToKrw: _isForeignToKrw,
              onAmountChanged: () => setState(() {}),
              onSwapDirection: _swapDirection,
              onShowSettlementNotice: _showSettlementNotice,
            ),
            const SizedBox(height: 20),
            const Text('환율 기준', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 10),
            _CountrySelector(
              selectedCountry: _selectedCountry,
              onChanged: _isLoading ? null : _selectCountry,
            ),
            const SizedBox(height: 12),
            _PeriodSelector(
              selectedPeriod: _selectedPeriod,
              customRange: _customRange,
              onSelect: _isLoading ? null : _selectPeriod,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: _errorMessage!, onRetry: _loadRates),
            ],
            const SizedBox(height: 14),
            _RateHistorySection(
              rates: _sortedRates,
              isLoading: _isLoading,
              currencyCode: _selectedCountry.currencyCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final ExchangeCountryOption selectedCountry;
  final ValueChanged<ExchangeCountryOption?>? onChanged;

  const _CountrySelector({
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '국가',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<ExchangeCountryOption>(
                value: selectedCountry,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: exchangeCountryOptions
                    .map(
                      (country) => DropdownMenuItem<ExchangeCountryOption>(
                        value: country,
                        child: Text(
                          '${country.countryName} · ${country.currencyCode}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final _ExchangePeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_ExchangePeriod>? onSelect;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.customRange,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(_ExchangePeriod, String)>[
      (_ExchangePeriod.today, '오늘'),
      (_ExchangePeriod.sevenDays, '7일'),
      (_ExchangePeriod.thirtyDays, '30일'),
      (_ExchangePeriod.custom, _customLabel),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = selectedPeriod == option.$1;
          return ChoiceChip(
            label: Text(option.$2),
            selected: selected,
            onSelected: onSelect == null ? null : (_) => onSelect!(option.$1),
            selectedColor: AppColors.brand,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: AppColors.lineSoft),
            ),
          );
        },
      ),
    );
  }

  String get _customLabel {
    final range = customRange;
    if (range == null) return '직접 선택';
    return '${_formatShortDate(range.start)}-${_formatShortDate(range.end)}';
  }
}

class _RateSummaryCard extends StatelessWidget {
  final ExchangeCountryOption country;
  final ExchangeRateRecord? latestRate;
  final bool isLoading;
  final TextEditingController amountController;
  final double? convertedAmount;
  final bool isForeignToKrw;
  final VoidCallback onAmountChanged;
  final VoidCallback onSwapDirection;
  final VoidCallback onShowSettlementNotice;

  const _RateSummaryCard({
    required this.country,
    required this.latestRate,
    required this.isLoading,
    required this.amountController,
    required this.convertedAmount,
    required this.isForeignToKrw,
    required this.onAmountChanged,
    required this.onSwapDirection,
    required this.onShowSettlementNotice,
  });

  @override
  Widget build(BuildContext context) {
    final rate = latestRate;
    final inputCurrency = isForeignToKrw ? country.currencyCode : 'KRW';
    final outputCurrency = isForeignToKrw ? 'KRW' : country.currencyCode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${country.countryName} ${country.currencyCode}',
                  style: const TextStyle(
                    color: AppColors.brandStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLoading && rate != null) ...[
                IconButton(
                  key: const ValueKey('exchangeSettlementNoticeButton'),
                  onPressed: onShowSettlementNotice,
                  icon: const Icon(Icons.info_outline),
                  color: AppColors.brandStrong,
                  tooltip: '정산 환율 안내',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  key: const ValueKey('exchangeSwapDirectionButton'),
                  onPressed: onSwapDirection,
                  icon: const Icon(Icons.swap_vert),
                  color: AppColors.brandStrong,
                  tooltip: '계산 방향 바꾸기',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Text(
              '환율을 불러오는 중입니다.',
              style: TextStyle(color: AppColors.ink, fontSize: 15),
            )
          else if (rate == null)
            const Text(
              '선택한 기간의 환율이 없습니다.',
              style: TextStyle(color: AppColors.ink, fontSize: 15),
            )
          else ...[
            Text(
              '1 ${rate.targetCurrency} = ${_formatRate(rate.rate)} KRW',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${rate.rateDate} 기준${rate.source == null ? '' : ' · ${rate.source}'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('exchangeAmountField'),
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_MoneyInputFormatter()],
              onChanged: (_) => onAmountChanged(),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                hintText: '금액 입력',
                suffixText: inputCurrency,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lineSoft),
              ),
              child: Row(
                children: [
                  const Text(
                    '계산 결과',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatMoney(convertedAmount, outputCurrency),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.brandStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateHistorySection extends StatelessWidget {
  final List<ExchangeRateRecord> rates;
  final bool isLoading;
  final String currencyCode;

  const _RateHistorySection({
    required this.rates,
    required this.isLoading,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (rates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: const Text(
          '기간이나 국가를 바꿔 다시 조회해보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSubtle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기간별 환율',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          child: Column(
            children: List.generate(rates.length, (index) {
              final rate = rates[index];
              final isLast = index == rates.length - 1;
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: isLast
                        ? BorderSide.none
                        : const BorderSide(color: Color(0xFFEDEDED)),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rate.rateDate,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatRate(rate.rate)} KRW',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD1D1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A1F1F)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('재시도')),
        ],
      ),
    );
  }
}

class _DateQuery {
  final String? date;
  final String? from;
  final String? to;

  const _DateQuery({this.date, this.from, this.to});
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatShortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month.$day';
}

String _formatRate(double value) {
  final text = value.toStringAsFixed(6);
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _formatMoney(double? value, String currency) {
  if (value == null) return '-';
  return '${_formatInputAmount(value)} $currency';
}

String _formatInputAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${buffer.toString()}.${parts[1]}';
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
