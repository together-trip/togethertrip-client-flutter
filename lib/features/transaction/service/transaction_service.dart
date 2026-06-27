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
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trips/$tripId/transactions/$transactionId',
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '거래 상세 응답이 비어 있습니다.');
    }

    return TransactionDetail.fromJson(data);
  }

  Future<TransactionDetail> createTransaction(
    int tripId,
    TransactionFormInput input,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/transactions',
        input.toJson(),
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '거래 생성 응답이 비어 있습니다.');
    }

    return TransactionDetail.fromJson(data);
  }

  Future<TransactionDetail> updateTransaction(
    int tripId,
    int transactionId,
    TransactionFormInput input,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.patch(
        '/api/trips/$tripId/transactions/$transactionId',
        input.toJson(),
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '거래 수정 응답이 비어 있습니다.');
    }

    return TransactionDetail.fromJson(data);
  }
}

class TransactionDetail {
  final TransactionSummary summary;
  final List<TransactionPayment> payments;
  final List<TransactionShare> shares;

  const TransactionDetail({
    required this.summary,
    required this.payments,
    required this.shares,
  });

  factory TransactionDetail.fromJson(Map<String, dynamic> json) {
    return TransactionDetail(
      summary: TransactionSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map(
            (item) => TransactionPayment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      shares: (json['shares'] as List<dynamic>? ?? [])
          .map(
            (item) => TransactionShare.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
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
  final String? category;
  final String? occurredAt;
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
    required this.category,
    required this.occurredAt,
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
      category: json['category'] as String?,
      occurredAt: json['occurredAt'] as String?,
      status: json['status'] as String? ?? '',
      createdByUserId: (json['createdByUserId'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class TransactionPayment {
  final int id;
  final int participantId;
  final String participantDisplayName;
  final double amount;

  const TransactionPayment({
    required this.id,
    required this.participantId,
    required this.participantDisplayName,
    required this.amount,
  });

  factory TransactionPayment.fromJson(Map<String, dynamic> json) {
    return TransactionPayment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      participantId: (json['participantId'] as num?)?.toInt() ?? 0,
      participantDisplayName: json['participantDisplayName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TransactionShare {
  final int id;
  final int participantId;
  final String participantDisplayName;
  final double shareAmount;
  final double? shareRatio;

  const TransactionShare({
    required this.id,
    required this.participantId,
    required this.participantDisplayName,
    required this.shareAmount,
    required this.shareRatio,
  });

  factory TransactionShare.fromJson(Map<String, dynamic> json) {
    return TransactionShare(
      id: (json['id'] as num?)?.toInt() ?? 0,
      participantId: (json['participantId'] as num?)?.toInt() ?? 0,
      participantDisplayName: json['participantDisplayName'] as String? ?? '',
      shareAmount: (json['shareAmount'] as num?)?.toDouble() ?? 0,
      shareRatio: (json['shareRatio'] as num?)?.toDouble(),
    );
  }
}

class TransactionFormInput {
  final String transactionType;
  final double amount;
  final String currency;
  final String? category;
  final String? occurredAt;
  final List<TransactionPaymentInput> payments;
  final List<TransactionShareInput> shares;

  const TransactionFormInput({
    required this.transactionType,
    required this.amount,
    required this.currency,
    this.category,
    this.occurredAt,
    required this.payments,
    required this.shares,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionType': transactionType,
      'amount': amount,
      'currency': currency,
      'category': category,
      'occurredAt': occurredAt,
      'payments': payments.map((payment) => payment.toJson()).toList(),
      'shares': shares.map((share) => share.toJson()).toList(),
    };
  }
}

class TransactionPaymentInput {
  final int participantId;
  final double amount;

  const TransactionPaymentInput({
    required this.participantId,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {'participantId': participantId, 'amount': amount};
  }
}

class TransactionShareInput {
  final int participantId;
  final double shareAmount;
  final double shareRatio;

  const TransactionShareInput({
    required this.participantId,
    required this.shareAmount,
    required this.shareRatio,
  });

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'shareAmount': shareAmount,
      'shareRatio': shareRatio,
    };
  }
}
