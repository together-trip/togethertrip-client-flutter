import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class TripService {
  final ApiClient _apiClient;
  final AuthService _authService;

  TripService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<TripListPage> getTrips({
    String? status,
    String? cursor,
    int size = 20,
  }) async {
    final accessToken = await _requireAccessToken();
    final queryParameters = <String, String>{'size': size.toString()};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final data = await _apiClient.get(
      '/api/trips',
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 목록 응답이 비어 있습니다.');
    }

    return TripListPage.fromJson(data);
  }

  Future<TripDetail> createTrip(TripFormInput input) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.post(
      '/api/trips',
      input.toCreateJson(),
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 생성 응답이 비어 있습니다.');
    }

    return TripDetail.fromJson(data);
  }

  Future<TripDetail> getTrip(int tripId) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.get(
      '/api/trips/$tripId',
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 상세 응답이 비어 있습니다.');
    }

    return TripDetail.fromJson(data);
  }

  Future<TripDetail> updateTrip(int tripId, TripFormInput input) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.patch(
      '/api/trips/$tripId',
      input.toUpdateJson(),
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 수정 응답이 비어 있습니다.');
    }

    return TripDetail.fromJson(data);
  }

  Future<TripCountries> updateTripCountries(
    int tripId,
    List<TripCountryInput> countries,
  ) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.put('/api/trips/$tripId/countries', {
      'countries': countries.map((country) => country.toJson()).toList(),
    }, accessToken: accessToken);
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 국가 응답이 비어 있습니다.');
    }

    return TripCountries.fromJson(data);
  }

  Future<void> deleteTrip(int tripId) async {
    final accessToken = await _requireAccessToken();
    await _apiClient.delete('/api/trips/$tripId', accessToken: accessToken);
  }

  Future<UserProfile> getCurrentUser() => _authService.getMe();

  Future<String> _requireAccessToken() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }
}

class TripListPage {
  final List<TripSummary> items;
  final int size;
  final String? nextCursor;
  final bool hasNext;

  const TripListPage({
    required this.items,
    required this.size,
    required this.nextCursor,
    required this.hasNext,
  });

  factory TripListPage.fromJson(Map<String, dynamic> json) {
    return TripListPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => TripSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}

class TripSummary {
  final int id;
  final String title;
  final String defaultCurrency;
  final String? startDate;
  final String? endDate;
  final String tripStatus;
  final String settlementStatus;
  final int ownerUserId;

  const TripSummary({
    required this.id,
    required this.title,
    required this.defaultCurrency,
    required this.startDate,
    required this.endDate,
    required this.tripStatus,
    required this.settlementStatus,
    required this.ownerUserId,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      defaultCurrency: json['defaultCurrency'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      tripStatus: json['tripStatus'] as String,
      settlementStatus: json['settlementStatus'] as String,
      ownerUserId: (json['ownerUserId'] as num).toInt(),
    );
  }
}

class TripDetail {
  final int id;
  final int ownerUserId;
  final String title;
  final String defaultCurrency;
  final String? exchangeRateBaseDate;
  final String? startDate;
  final String? endDate;
  final String tripStatus;
  final String settlementStatus;
  final String? settledAt;
  final List<TripCountry> countries;
  final List<TripParticipant> participants;

  const TripDetail({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.defaultCurrency,
    required this.exchangeRateBaseDate,
    required this.startDate,
    required this.endDate,
    required this.tripStatus,
    required this.settlementStatus,
    required this.settledAt,
    required this.countries,
    required this.participants,
  });

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    return TripDetail(
      id: (json['id'] as num).toInt(),
      ownerUserId: (json['ownerUserId'] as num).toInt(),
      title: json['title'] as String,
      defaultCurrency: json['defaultCurrency'] as String,
      exchangeRateBaseDate: json['exchangeRateBaseDate'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      tripStatus: json['tripStatus'] as String,
      settlementStatus: json['settlementStatus'] as String,
      settledAt: json['settledAt'] as String?,
      countries: (json['countries'] as List<dynamic>? ?? [])
          .map((item) => TripCountry.fromJson(item as Map<String, dynamic>))
          .toList(),
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((item) => TripParticipant.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  TripSummary toSummary() {
    return TripSummary(
      id: id,
      title: title,
      defaultCurrency: defaultCurrency,
      startDate: startDate,
      endDate: endDate,
      tripStatus: tripStatus,
      settlementStatus: settlementStatus,
      ownerUserId: ownerUserId,
    );
  }
}

class TripCountry {
  final int id;
  final String countryCode;
  final String countryName;
  final int sortOrder;

  const TripCountry({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.sortOrder,
  });

  factory TripCountry.fromJson(Map<String, dynamic> json) {
    return TripCountry(
      id: (json['id'] as num).toInt(),
      countryCode: json['countryCode'] as String,
      countryName: json['countryName'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
    );
  }
}

class TripParticipant {
  final int id;
  final int? userId;
  final String displayName;
  final String? profileImageUrl;
  final String participantRole;
  final String participantStatus;
  final String? joinedAt;

  const TripParticipant({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.profileImageUrl,
    required this.participantRole,
    required this.participantStatus,
    required this.joinedAt,
  });

  factory TripParticipant.fromJson(Map<String, dynamic> json) {
    return TripParticipant(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      displayName: json['displayName'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      participantRole: json['participantRole'] as String,
      participantStatus: json['participantStatus'] as String,
      joinedAt: json['joinedAt'] as String?,
    );
  }
}

class TripCountries {
  final int tripId;
  final List<TripCountry> countries;

  const TripCountries({required this.tripId, required this.countries});

  factory TripCountries.fromJson(Map<String, dynamic> json) {
    return TripCountries(
      tripId: (json['tripId'] as num).toInt(),
      countries: (json['countries'] as List<dynamic>? ?? [])
          .map((item) => TripCountry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TripFormInput {
  final String title;
  final String defaultCurrency;
  final String? exchangeRateBaseDate;
  final String? startDate;
  final String? endDate;
  final List<TripCountryInput> countries;
  final List<TripCompanionInput> participants;

  const TripFormInput({
    required this.title,
    required this.defaultCurrency,
    required this.exchangeRateBaseDate,
    required this.startDate,
    required this.endDate,
    required this.countries,
    required this.participants,
  });

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'defaultCurrency': defaultCurrency,
      'exchangeRateBaseDate': exchangeRateBaseDate,
      'startDate': startDate,
      'endDate': endDate,
      'countries': countries.map((country) => country.toJson()).toList(),
      'participants': participants
          .map((participant) => participant.toJson())
          .toList(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'defaultCurrency': defaultCurrency,
      'exchangeRateBaseDate': exchangeRateBaseDate,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}

class TripCountryInput {
  final String countryCode;
  final String countryName;
  final int? sortOrder;

  const TripCountryInput({
    required this.countryCode,
    required this.countryName,
    this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'countryCode': countryCode,
      'countryName': countryName,
      'sortOrder': sortOrder,
    };
  }
}

class TripCompanionInput {
  final String displayName;
  final String? profileImageUrl;

  const TripCompanionInput({
    required this.displayName,
    required this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {'displayName': displayName, 'profileImageUrl': profileImageUrl};
  }
}
