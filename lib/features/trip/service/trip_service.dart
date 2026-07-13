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
    final queryParameters = <String, String>{'size': size.toString()};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trips',
        queryParameters: queryParameters,
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 목록 응답이 비어 있습니다.');
    }

    return TripListPage.fromJson(data);
  }

  Future<TripDetail> createTrip(TripFormInput input) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips',
        input.toCreateJson(),
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 생성 응답이 비어 있습니다.');
    }

    return TripDetail.fromJson(data);
  }

  Future<UserSearchResult> searchUserByNickname(String nickname) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post('/api/users/search/nickname', {
        'nickname': nickname,
      }, accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '사용자 검색 응답이 비어 있습니다.');
    }

    return UserSearchResult.fromJson(data);
  }

  Future<TripInvite> createInviteLink(int tripId, {int? participantId}) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/invite-links',
        const {},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '초대 링크 응답이 비어 있습니다.');
    }

    final invite = TripInvite.fromJson(data);
    if (participantId == null) return invite;

    return invite.copyWith(
      inviteUrl: _appendParticipantId(
        invite.inviteUrl,
        participantId: participantId,
      ),
    );
  }

  Future<TripInvite> createInviteCode(int tripId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/invite-codes',
        const {},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '초대 코드 응답이 비어 있습니다.');
    }

    return TripInvite.fromJson(data);
  }

  Future<TripParticipant> addTemporaryParticipant(
    int tripId,
    TripCompanionInput input,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/participants',
        input.toJson(),
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '참여자 추가 응답이 비어 있습니다.');
    }

    return TripParticipant.fromJson(data);
  }

  Future<TripParticipant> linkParticipant(
    int tripId, {
    required int participantId,
    required int userId,
  }) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/participant-connections',
        {'participantId': participantId, 'userId': userId},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '참여자 연결 응답이 비어 있습니다.');
    }

    return TripParticipant.fromJson(data);
  }

  Future<void> removeParticipant(int tripId, int participantId) async {
    await _authService.runWithAccessToken(
      (accessToken) => _apiClient.delete(
        '/api/trips/$tripId/participants/$participantId',
        accessToken: accessToken,
      ),
    );
  }

  Future<TripInviteInfo> getInviteInfo({String? code, String? token}) async {
    final queryParameters = <String, String>{};
    if (code != null && code.trim().isNotEmpty) {
      queryParameters['code'] = code.trim();
    }
    if (token != null && token.trim().isNotEmpty) {
      queryParameters['token'] = token.trim();
    }
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trip-invites',
        queryParameters: queryParameters,
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '초대 정보 응답이 비어 있습니다.');
    }

    return TripInviteInfo.fromJson(data);
  }

  Future<JoinTripResult> joinTrip({
    String? code,
    String? token,
    int? participantId,
  }) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post('/api/trip-invite-joins', {
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
        ...?participantId == null ? null : {'participantId': participantId},
      }, accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '초대 참여 응답이 비어 있습니다.');
    }

    return JoinTripResult.fromJson(data);
  }

  Future<TripDetail> getTrip(int tripId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) =>
          _apiClient.get('/api/trips/$tripId', accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 상세 응답이 비어 있습니다.');
    }

    return TripDetail.fromJson(data);
  }

  Future<TripDetail> updateTrip(int tripId, TripFormInput input) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.patch(
        '/api/trips/$tripId',
        input.toUpdateJson(),
        accessToken: accessToken,
      ),
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
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.put('/api/trips/$tripId/countries', {
        'countries': countries.map((country) => country.toJson()).toList(),
      }, accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '여행 국가 응답이 비어 있습니다.');
    }

    return TripCountries.fromJson(data);
  }

  Future<void> deleteTrip(int tripId) async {
    await _authService.runWithAccessToken(
      (accessToken) =>
          _apiClient.delete('/api/trips/$tripId', accessToken: accessToken),
    );
  }

  Future<TripParticipant> getMyTripParticipant(int tripId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/users/me/trip-participants',
        queryParameters: {'tripId': tripId.toString()},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '내 여행 참여자 응답이 비어 있습니다.',
      );
    }

    return TripParticipant.fromJson(data);
  }

  Future<UserProfile> getCurrentUser() => _authService.getMe();

  Future<TripRecapStatus> getRecapStatus(int tripId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trips/$tripId/recap/status',
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Recap 상태 응답이 비어 있습니다.',
      );
    }

    return TripRecapStatus.fromJson(data);
  }

  Future<TripRecapCreateResult> createRecap(
    int tripId,
    TripRecapStyle style,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post('/api/trips/$tripId/recap', {
        'style': style.apiValue,
      }, accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Recap 생성 응답이 비어 있습니다.',
      );
    }

    return TripRecapCreateResult.fromJson(data);
  }

  Future<TripRecapCreateResult> retryRecap(
    int tripId,
    TripRecapStyle style,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post('/api/trips/$tripId/recap/retry', {
        'style': style.apiValue,
      }, accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Recap 재시도 응답이 비어 있습니다.',
      );
    }

    return TripRecapCreateResult.fromJson(data);
  }

  Future<TripRecap> getRecap(int tripId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) =>
          _apiClient.get('/api/trips/$tripId/recap', accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: 'Recap 응답이 비어 있습니다.');
    }

    return TripRecap.fromJson(data);
  }

  Future<List<int>> getRecapSceneImageBytes(String imageUrl) {
    return _authService.runWithAccessToken(
      (accessToken) => _apiClient.getBytes(imageUrl, accessToken: accessToken),
    );
  }

  String _appendParticipantId(String inviteUrl, {required int participantId}) {
    final uri = Uri.tryParse(inviteUrl);
    if (uri == null) {
      final separator = inviteUrl.contains('?') ? '&' : '?';
      return '$inviteUrl${separator}participantId=$participantId';
    }

    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'participantId': participantId.toString(),
          },
        )
        .toString();
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

enum TripRecapStatusValue { none, creating, completed, failed }

enum TripRecapStyle {
  photo('PHOTO', '현실 사진 느낌'),
  illustration('ILLUSTRATION', '일러스트/감성 포스터 느낌');

  final String apiValue;
  final String label;

  const TripRecapStyle(this.apiValue, this.label);

  static TripRecapStyle? fromName(String? value) {
    return switch (value) {
      'PHOTO' => TripRecapStyle.photo,
      'ILLUSTRATION' => TripRecapStyle.illustration,
      _ => null,
    };
  }
}

class TripRecapStatus {
  final bool available;
  final TripRecapStatusValue status;
  final int? recapId;
  final TripRecapStyle? style;

  const TripRecapStatus({
    required this.available,
    required this.status,
    required this.recapId,
    required this.style,
  });

  factory TripRecapStatus.fromJson(Map<String, dynamic> json) {
    return TripRecapStatus(
      available: json['available'] as bool? ?? false,
      status: _recapStatusFromName(json['status'] as String?),
      recapId: (json['recapId'] as num?)?.toInt(),
      style: TripRecapStyle.fromName(json['style'] as String?),
    );
  }

  TripRecapStatus copyWith({
    bool? available,
    TripRecapStatusValue? status,
    int? recapId,
    TripRecapStyle? style,
  }) {
    return TripRecapStatus(
      available: available ?? this.available,
      status: status ?? this.status,
      recapId: recapId ?? this.recapId,
      style: style ?? this.style,
    );
  }
}

class TripRecapCreateResult {
  final int recapId;
  final TripRecapStatusValue status;

  const TripRecapCreateResult({required this.recapId, required this.status});

  factory TripRecapCreateResult.fromJson(Map<String, dynamic> json) {
    return TripRecapCreateResult(
      recapId: (json['recapId'] as num).toInt(),
      status: _recapStatusFromName(json['status'] as String?),
    );
  }
}

class TripRecap {
  final int recapId;
  final int tripId;
  final TripRecapStyle? style;
  final TripRecapStatusValue status;
  final List<TripRecapScene> scenes;

  const TripRecap({
    required this.recapId,
    required this.tripId,
    required this.style,
    required this.status,
    required this.scenes,
  });

  factory TripRecap.fromJson(Map<String, dynamic> json) {
    return TripRecap(
      recapId: (json['recapId'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      style: TripRecapStyle.fromName(json['style'] as String?),
      status: _recapStatusFromName(json['status'] as String?),
      scenes: (json['scenes'] as List<dynamic>? ?? [])
          .map((item) => TripRecapScene.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TripRecapScene {
  final int sceneId;
  final int order;
  final String imageUrl;
  final String? aspectRatio;

  const TripRecapScene({
    required this.sceneId,
    required this.order,
    required this.imageUrl,
    required this.aspectRatio,
  });

  double get numericAspectRatio {
    final value = aspectRatio;
    if (value == null || !value.contains(':')) return 9 / 16;
    final parts = value.split(':');
    final width = double.tryParse(parts[0]);
    final height = double.tryParse(parts[1]);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 9 / 16;
    }
    return width / height;
  }

  factory TripRecapScene.fromJson(Map<String, dynamic> json) {
    return TripRecapScene(
      sceneId: (json['sceneId'] as num).toInt(),
      order: (json['order'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      aspectRatio: json['aspectRatio'] as String?,
    );
  }
}

TripRecapStatusValue _recapStatusFromName(String? value) {
  return switch (value) {
    'CREATING' => TripRecapStatusValue.creating,
    'COMPLETED' => TripRecapStatusValue.completed,
    'FAILED' => TripRecapStatusValue.failed,
    _ => TripRecapStatusValue.none,
  };
}

class TripSummary {
  final int id;
  final String title;
  final String defaultCurrency;
  final String? startDate;
  final String? endDate;
  final String tripStatus;
  final String settlementStatus;
  final String? settlementDisplayStatus;
  final int ownerUserId;

  const TripSummary({
    required this.id,
    required this.title,
    required this.defaultCurrency,
    required this.startDate,
    required this.endDate,
    required this.tripStatus,
    required this.settlementStatus,
    this.settlementDisplayStatus,
    required this.ownerUserId,
  });

  String get effectiveSettlementDisplayStatus {
    return settlementDisplayStatus ??
        _fallbackSettlementDisplayStatus(settlementStatus);
  }

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      defaultCurrency: json['defaultCurrency'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      tripStatus: json['tripStatus'] as String,
      settlementStatus: json['settlementStatus'] as String,
      settlementDisplayStatus: json['settlementDisplayStatus'] as String?,
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
  final String? settlementDisplayStatus;
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
    this.settlementDisplayStatus,
    required this.settledAt,
    required this.countries,
    required this.participants,
  });

  String get effectiveSettlementDisplayStatus {
    return settlementDisplayStatus ??
        _fallbackSettlementDisplayStatus(settlementStatus);
  }

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
      settlementDisplayStatus: json['settlementDisplayStatus'] as String?,
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
      settlementDisplayStatus: effectiveSettlementDisplayStatus,
      ownerUserId: ownerUserId,
    );
  }
}

String _fallbackSettlementDisplayStatus(String settlementStatus) {
  return switch (settlementStatus) {
    'SETTLED' => 'COMPLETED',
    'IN_PROGRESS' => 'IN_PROGRESS',
    _ => 'NOT_STARTED',
  };
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
  final int? userId;

  const TripCompanionInput({
    required this.displayName,
    required this.profileImageUrl,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      if (userId != null) 'userId': userId,
    };
  }
}

class UserSearchResult {
  final bool found;
  final UserSearchUser? user;

  const UserSearchResult({required this.found, required this.user});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      found: json['found'] as bool? ?? false,
      user: json['user'] == null
          ? null
          : UserSearchUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserSearchUser {
  final int userId;
  final String nickname;
  final String? profileImageUrl;

  const UserSearchUser({
    required this.userId,
    required this.nickname,
    required this.profileImageUrl,
  });

  factory UserSearchUser.fromJson(Map<String, dynamic> json) {
    return UserSearchUser(
      userId: (json['userId'] as num).toInt(),
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}

class TripInvite {
  final int id;
  final int tripId;
  final String type;
  final String? code;
  final String token;
  final String inviteUrl;
  final String invitationStatus;
  final String? expiresAt;

  const TripInvite({
    required this.id,
    required this.tripId,
    required this.type,
    required this.code,
    required this.token,
    required this.inviteUrl,
    required this.invitationStatus,
    required this.expiresAt,
  });

  factory TripInvite.fromJson(Map<String, dynamic> json) {
    return TripInvite(
      id: (json['id'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      type: json['type'] as String,
      code: json['code'] as String?,
      token: json['token'] as String,
      inviteUrl: json['inviteUrl'] as String,
      invitationStatus: json['invitationStatus'] as String,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  TripInvite copyWith({String? inviteUrl}) {
    return TripInvite(
      id: id,
      tripId: tripId,
      type: type,
      code: code,
      token: token,
      inviteUrl: inviteUrl ?? this.inviteUrl,
      invitationStatus: invitationStatus,
      expiresAt: expiresAt,
    );
  }
}

class TripInviteInfo {
  final int invitationId;
  final String type;
  final String? code;
  final String invitationStatus;
  final String? expiresAt;
  final TripSummary trip;
  final bool alreadyJoined;

  const TripInviteInfo({
    required this.invitationId,
    required this.type,
    required this.code,
    required this.invitationStatus,
    required this.expiresAt,
    required this.trip,
    required this.alreadyJoined,
  });

  factory TripInviteInfo.fromJson(Map<String, dynamic> json) {
    return TripInviteInfo(
      invitationId: (json['invitationId'] as num).toInt(),
      type: json['type'] as String,
      code: json['code'] as String?,
      invitationStatus: json['invitationStatus'] as String,
      expiresAt: json['expiresAt'] as String?,
      trip: TripSummary.fromJson(json['trip'] as Map<String, dynamic>),
      alreadyJoined: json['alreadyJoined'] as bool? ?? false,
    );
  }
}

class JoinTripResult {
  final int tripId;
  final TripParticipant participant;
  final int invitationId;

  const JoinTripResult({
    required this.tripId,
    required this.participant,
    required this.invitationId,
  });

  factory JoinTripResult.fromJson(Map<String, dynamic> json) {
    return JoinTripResult(
      tripId: (json['tripId'] as num).toInt(),
      participant: TripParticipant.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      invitationId: (json['invitationId'] as num).toInt(),
    );
  }
}
