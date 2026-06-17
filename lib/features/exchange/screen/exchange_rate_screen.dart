import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../trip/service/trip_service.dart';
import '../model/exchange_rate_models.dart';
import '../service/exchange_rate_service.dart';

class ExchangeRateScreen extends StatefulWidget {
  final TripService? tripService;
  final ExchangeRateService? exchangeRateService;

  const ExchangeRateScreen({
    super.key,
    this.tripService,
    this.exchangeRateService,
  });

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  late final TripService _tripService;
  late final ExchangeRateService _exchangeRateService;
  final TextEditingController _amountController = TextEditingController(
    text: '1000',
  );

  List<TripSummary> _trips = [];
  TripSummary? _selectedTrip;
  String _selectedCurrency = 'JPY';
  ExchangeRatePreview? _preview;
  bool _isLoadingTrips = true;
  bool _isLoadingRate = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _exchangeRateService = widget.exchangeRateService ?? ExchangeRateService();
    _loadTrips();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoadingTrips = true;
      _errorMessage = null;
    });

    try {
      final page = await _tripService.getTrips(size: 50);
      if (!mounted) return;
      final trips = page.items;
      setState(() {
        _trips = trips;
        _selectedTrip = trips.isEmpty ? null : trips.first;
        _selectedCurrency = _initialCurrencyFor(trips);
      });
      if (trips.isNotEmpty) {
        await _loadRate();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '환율 화면을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTrips = false);
    }
  }

  Future<void> _loadRate() async {
    final selectedTrip = _selectedTrip;
    if (selectedTrip == null) return;

    setState(() {
      _isLoadingRate = true;
      _errorMessage = null;
    });

    try {
      final preview = await _exchangeRateService
          .getTransactionExchangeRatePreview(
            tripId: selectedTrip.id,
            currency: _selectedCurrency,
          );
      if (!mounted) return;
      setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _errorMessage = '환율을 불러오지 못했습니다: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoadingRate = false);
    }
  }

  String _initialCurrencyFor(List<TripSummary> trips) {
    final defaultCurrency = trips.isEmpty ? null : trips.first.defaultCurrency;
    if (defaultCurrency == null || defaultCurrency == 'KRW') return 'JPY';
    return defaultCurrency;
  }

  void _selectTrip(TripSummary trip) {
    if (_selectedTrip?.id == trip.id) return;
    setState(() {
      _selectedTrip = trip;
      if (trip.defaultCurrency != 'KRW') {
        _selectedCurrency = trip.defaultCurrency;
      }
    });
    _loadRate();
  }

  void _selectCurrency(String currency) {
    if (_selectedCurrency == currency) return;
    setState(() => _selectedCurrency = currency);
    _loadRate();
  }

  double get _inputAmount {
    final normalized = _amountController.text.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  double? get _convertedAmount {
    final preview = _preview;
    if (preview == null) return null;
    return _inputAmount * preview.rate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '환율',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('exchangeRefreshButton'),
            onPressed: _isLoadingTrips || _isLoadingRate ? null : _loadRate,
            icon: const Icon(Icons.refresh, size: 22),
            color: const Color(0xFF1A1A1A),
            tooltip: '환율 새로고침',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingTrips) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_trips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 92, 20, 120),
        children: [
          const Icon(Icons.travel_explore, size: 36, color: Color(0xFF8A8A8A)),
          const SizedBox(height: 14),
          const Text(
            '환율을 확인할 여행이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '여행을 만든 뒤 지출에 사용할 통화 환율을 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _loadTrips, child: const Text('다시 불러오기')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRate,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          _TripSelector(
            trips: _trips,
            selectedTrip: _selectedTrip,
            onSelect: _selectTrip,
          ),
          const SizedBox(height: 14),
          _CurrencySelector(
            selectedCurrency: _selectedCurrency,
            onSelect: _selectCurrency,
          ),
          const SizedBox(height: 14),
          _ConverterCard(
            amountController: _amountController,
            preview: _preview,
            convertedAmount: _convertedAmount,
            isLoading: _isLoadingRate,
            onChanged: () => setState(() {}),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(message: _errorMessage!, onRetry: _loadRate),
          ],
          const SizedBox(height: 14),
          _RateInfoCard(preview: _preview, isLoading: _isLoadingRate),
        ],
      ),
    );
  }
}

class _TripSelector extends StatelessWidget {
  final List<TripSummary> trips;
  final TripSummary? selectedTrip;
  final ValueChanged<TripSummary> onSelect;

  const _TripSelector({
    required this.trips,
    required this.selectedTrip,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '여행',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B6B6B),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<TripSummary>(
                value: selectedTrip,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: trips
                    .map(
                      (trip) => DropdownMenuItem<TripSummary>(
                        value: trip,
                        child: Text(
                          '${trip.title} · ${trip.defaultCurrency}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (trip) {
                  if (trip != null) onSelect(trip);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onSelect;

  const _CurrencySelector({
    required this.selectedCurrency,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exchangeCurrencyOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = exchangeCurrencyOptions[index];
          final selected = selectedCurrency == option.code;
          return ChoiceChip(
            label: Text(option.code),
            selected: selected,
            onSelected: (_) => onSelect(option.code),
            selectedColor: const Color(0xFF1A1A1A),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Color(0xFFE2E2E2)),
            ),
          );
        },
      ),
    );
  }
}

class _ConverterCard extends StatelessWidget {
  final TextEditingController amountController;
  final ExchangeRatePreview? preview;
  final double? convertedAmount;
  final bool isLoading;
  final VoidCallback onChanged;

  const _ConverterCard({
    required this.amountController,
    required this.preview,
    required this.convertedAmount,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final targetCurrency = preview?.targetCurrency ?? '외화';
    final baseCurrency = preview?.baseCurrency ?? 'KRW';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '간단 환산',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('exchangeAmountField'),
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: '$targetCurrency 금액',
              border: const OutlineInputBorder(),
              suffixText: targetCurrency,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$baseCurrency 환산',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoading
                      ? '불러오는 중...'
                      : _formatMoney(convertedAmount, baseCurrency),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateInfoCard extends StatelessWidget {
  final ExchangeRatePreview? preview;
  final bool isLoading;

  const _RateInfoCard({required this.preview, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '적용 환율',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Text(
              '환율을 불러오는 중입니다.',
              style: TextStyle(color: Colors.white70),
            )
          else if (preview == null)
            const Text(
              '통화를 선택하면 여행 지출에 적용할 환율을 확인할 수 있어요.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            )
          else ...[
            Text(
              '1 ${preview.targetCurrency} = ${_formatRate(preview.rate)} ${preview.baseCurrency}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.rateDate} 기준${preview.source == null ? '' : ' · ${preview.source}'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
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
          const Icon(Icons.error_outline, color: Color(0xFFCC0000), size: 20),
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

String _formatRate(double value) {
  final text = value.toStringAsFixed(6);
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _formatMoney(double? value, String currency) {
  if (value == null) return '-';
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${buffer.toString()} $currency';
}
