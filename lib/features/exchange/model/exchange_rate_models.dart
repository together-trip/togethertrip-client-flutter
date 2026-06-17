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

class ExchangeRateSearchResult {
  final String baseCurrency;
  final String? date;
  final String? from;
  final String? to;
  final List<ExchangeRateRecord> rates;

  const ExchangeRateSearchResult({
    required this.baseCurrency,
    required this.date,
    required this.from,
    required this.to,
    required this.rates,
  });

  factory ExchangeRateSearchResult.fromJson(Map<String, dynamic> json) {
    return ExchangeRateSearchResult(
      baseCurrency: json['baseCurrency'] as String,
      date: json['date'] as String?,
      from: json['from'] as String?,
      to: json['to'] as String?,
      rates: (json['rates'] as List<dynamic>? ?? const [])
          .map(
            (rate) => ExchangeRateRecord.fromJson(rate as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ExchangeRateRecord {
  final String targetCurrency;
  final double rate;
  final String rateDate;
  final String? source;

  const ExchangeRateRecord({
    required this.targetCurrency,
    required this.rate,
    required this.rateDate,
    required this.source,
  });

  factory ExchangeRateRecord.fromJson(Map<String, dynamic> json) {
    return ExchangeRateRecord(
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

class ExchangeCountryOption {
  final String countryCode;
  final String countryName;
  final String currencyCode;
  final String currencyName;

  const ExchangeCountryOption({
    required this.countryCode,
    required this.countryName,
    required this.currencyCode,
    required this.currencyName,
  });
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

const exchangeCountryOptions = <ExchangeCountryOption>[
  ExchangeCountryOption(
    countryCode: 'JP',
    countryName: '일본',
    currencyCode: 'JPY',
    currencyName: '엔',
  ),
  ExchangeCountryOption(
    countryCode: 'US',
    countryName: '미국',
    currencyCode: 'USD',
    currencyName: '달러',
  ),
  ExchangeCountryOption(
    countryCode: 'EU',
    countryName: '유럽',
    currencyCode: 'EUR',
    currencyName: '유로',
  ),
  ExchangeCountryOption(
    countryCode: 'CN',
    countryName: '중국',
    currencyCode: 'CNY',
    currencyName: '위안',
  ),
  ExchangeCountryOption(
    countryCode: 'TW',
    countryName: '대만',
    currencyCode: 'TWD',
    currencyName: '달러',
  ),
  ExchangeCountryOption(
    countryCode: 'HK',
    countryName: '홍콩',
    currencyCode: 'HKD',
    currencyName: '달러',
  ),
  ExchangeCountryOption(
    countryCode: 'VN',
    countryName: '베트남',
    currencyCode: 'VND',
    currencyName: '동',
  ),
  ExchangeCountryOption(
    countryCode: 'TH',
    countryName: '태국',
    currencyCode: 'THB',
    currencyName: '바트',
  ),
  ExchangeCountryOption(
    countryCode: 'SG',
    countryName: '싱가포르',
    currencyCode: 'SGD',
    currencyName: '달러',
  ),
];
