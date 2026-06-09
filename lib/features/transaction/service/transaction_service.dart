import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class TransactionService {
  final ApiClient _apiClient;
  final AuthService _authService;

  TransactionService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<TransactionDetail> getTransaction(
    int tripId,
    int transactionId,
  ) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.get(
      '/api/trips/$tripId/transactions/$transactionId',
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '거래 상세 응답이 비어 있습니다.');
    }

    return TransactionDetail.fromJson(data);
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }
}

class TransactionDetail {
  final TransactionSummary summary;

  const TransactionDetail({required this.summary});

  factory TransactionDetail.fromJson(Map<String, dynamic> json) {
    return TransactionDetail(
      summary: TransactionSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
    );
  }
}

class TransactionSummary {
  final int id;
  final int tripId;
  final String transactionType;
  final double amount;
  final String currency;
  final double? exchangeRate;
  final String? baseCurrency;
  final double? baseAmount;
  final String status;
  final int? createdByUserId;
  final String? createdAt;
  final String? updatedAt;

  const TransactionSummary({
    required this.id,
    required this.tripId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.baseCurrency,
    required this.baseAmount,
    required this.status,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      id: (json['id'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      transactionType: json['transactionType'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      baseCurrency: json['baseCurrency'] as String?,
      baseAmount: (json['baseAmount'] as num?)?.toDouble(),
      status: json['status'] as String? ?? '',
      createdByUserId: (json['createdByUserId'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
