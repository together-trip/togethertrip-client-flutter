enum ReportTargetType {
  post('POST'),
  comment('COMMENT'),
  user('USER'),
  tripRecap('TRIP_RECAP');

  const ReportTargetType(this.apiValue);

  final String apiValue;
}

enum ReportReason {
  spam('SPAM', '스팸 또는 광고'),
  harassment('HARASSMENT', '괴롭힘 또는 따돌림'),
  hateSpeech('HATE_SPEECH', '혐오 발언'),
  sexualContent('SEXUAL_CONTENT', '성적인 콘텐츠'),
  violence('VIOLENCE', '폭력적이거나 위험한 콘텐츠'),
  privacy('PRIVACY', '개인정보 노출'),
  other('OTHER', '기타');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class ReportRequest {
  const ReportRequest({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
  });

  final ReportTargetType targetType;
  final int targetId;
  final ReportReason reason;
  final String? description;

  Map<String, dynamic> toJson() => {
    'targetType': targetType.apiValue,
    'targetId': targetId,
    'reason': reason.apiValue,
    if (description?.trim().isNotEmpty ?? false)
      'description': description!.trim(),
  };
}

class ReportResult {
  const ReportResult({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String status;
  final String? createdAt;

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
    id: (json['id'] as num).toInt(),
    status: json['status'] as String? ?? 'RECEIVED',
    createdAt: json['createdAt'] as String?,
  );
}

class BlockedUser {
  const BlockedUser({
    required this.blockedUserId,
    required this.displayName,
    required this.blockedAt,
  });

  final int blockedUserId;
  final String displayName;
  final String? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    blockedUserId: (json['blockedUserId'] as num).toInt(),
    displayName: json['displayName'] as String? ?? '알 수 없는 사용자',
    blockedAt: json['blockedAt'] as String?,
  );
}
