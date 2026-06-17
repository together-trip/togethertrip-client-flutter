class ExchangeRatePreview {
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final String rateDate;
  final String? source;

  const ExchangeRatePreview({
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.rateDate,
    required this.source,
  });

  factory ExchangeRatePreview.fromJson(Map<String, dynamic> json) {
    return ExchangeRatePreview(
      baseCurrency: json['baseCurrency'] as String,
      targetCurrency: json['targetCurrency'] as String,
      rate: (json['rate'] as num).toDouble(),
      rateDate: json['rateDate'] as String,
      source: json['source'] as String?,
    );
  }
}

class ExchangeCurrencyOption {
  final String code;
  final String label;

  const ExchangeCurrencyOption({required this.code, required this.label});
}

const exchangeCurrencyOptions = <ExchangeCurrencyOption>[
  ExchangeCurrencyOption(code: 'JPY', label: '일본 엔'),
  ExchangeCurrencyOption(code: 'USD', label: '미국 달러'),
  ExchangeCurrencyOption(code: 'EUR', label: '유로'),
  ExchangeCurrencyOption(code: 'CNY', label: '중국 위안'),
  ExchangeCurrencyOption(code: 'TWD', label: '대만 달러'),
  ExchangeCurrencyOption(code: 'HKD', label: '홍콩 달러'),
  ExchangeCurrencyOption(code: 'VND', label: '베트남 동'),
  ExchangeCurrencyOption(code: 'THB', label: '태국 바트'),
  ExchangeCurrencyOption(code: 'SGD', label: '싱가포르 달러'),
];
