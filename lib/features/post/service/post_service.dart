import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class PostService {
  final ApiClient _apiClient;
  final AuthService _authService;

  PostService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<PostListPage> getPosts(
    int tripId, {
    String? postType,
    String? cursor,
    int size = 20,
  }) async {
    final accessToken = await _requireAccessToken();
    final queryParameters = <String, String>{'size': size.toString()};
    if (postType != null && postType.isNotEmpty) {
      queryParameters['postType'] = postType;
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final data = await _apiClient.get(
      '/api/trips/$tripId/posts',
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '게시글 목록 응답이 비어 있습니다.');
    }

    return PostListPage.fromJson(data);
  }

  Future<PostDetail> getPost(int tripId, int postId) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.get(
      '/api/trips/$tripId/posts/$postId',
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '게시글 상세 응답이 비어 있습니다.');
    }

    return PostDetail.fromJson(data);
  }

  Future<PostDetail> createPost(int tripId, PostFormInput input) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.multipart(
      'POST',
      '/api/trips/$tripId/posts',
      fields: input.toCreateFields(),
      files: input.toMultipartFiles(),
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '게시글 작성 응답이 비어 있습니다.');
    }

    return PostDetail.fromJson(data);
  }

  Future<PostDetail> updatePost(
    int tripId,
    int postId,
    PostFormInput input,
  ) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.multipart(
      'PATCH',
      '/api/trips/$tripId/posts/$postId',
      fields: input.toUpdateFields(),
      files: input.toMultipartFiles(),
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '게시글 수정 응답이 비어 있습니다.');
    }

    return PostDetail.fromJson(data);
  }

  Future<void> deletePost(int tripId, int postId) async {
    final accessToken = await _requireAccessToken();
    await _apiClient.delete(
      '/api/trips/$tripId/posts/$postId',
      accessToken: accessToken,
    );
  }

  Future<PostCommentListPage> getComments(
    int tripId,
    int postId, {
    String? cursor,
    int size = 30,
  }) async {
    final accessToken = await _requireAccessToken();
    final queryParameters = <String, String>{'size': size.toString()};
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final data = await _apiClient.get(
      '/api/trips/$tripId/posts/$postId/comments',
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '댓글 목록 응답이 비어 있습니다.');
    }

    return PostCommentListPage.fromJson(data);
  }

  Future<PostComment> createComment(
    int tripId,
    int postId,
    String content,
  ) async {
    final accessToken = await _requireAccessToken();
    final data = await _apiClient.post(
      '/api/trips/$tripId/posts/$postId/comments',
      {'content': content},
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '댓글 작성 응답이 비어 있습니다.');
    }

    return PostComment.fromJson(data);
  }

  Future<void> deleteComment(int tripId, int postId, int commentId) async {
    final accessToken = await _requireAccessToken();
    await _apiClient.delete(
      '/api/trips/$tripId/posts/$postId/comments/$commentId',
      accessToken: accessToken,
    );
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }
}

class PostListPage {
  final List<PostSummary> items;
  final int size;
  final String? nextCursor;
  final bool hasNext;

  const PostListPage({
    required this.items,
    required this.size,
    required this.nextCursor,
    required this.hasNext,
  });

  factory PostListPage.fromJson(Map<String, dynamic> json) {
    return PostListPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => PostSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}

class PostSummary {
  final int id;
  final int tripId;
  final int? transactionId;
  final int authorParticipantId;
  final String authorDisplayName;
  final String postType;
  final String title;
  final String category;
  final String? contentPreview;
  final String? occurredAt;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int commentCount;
  final List<PostAttachment> attachments;
  final String? createdAt;
  final String? updatedAt;

  const PostSummary({
    required this.id,
    required this.tripId,
    required this.transactionId,
    required this.authorParticipantId,
    required this.authorDisplayName,
    required this.postType,
    required this.title,
    required this.category,
    required this.contentPreview,
    required this.occurredAt,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.commentCount,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) {
    return PostSummary(
      id: (json['id'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      transactionId: (json['transactionId'] as num?)?.toInt(),
      authorParticipantId: (json['authorParticipantId'] as num).toInt(),
      authorDisplayName: json['authorDisplayName'] as String? ?? '',
      postType: json['postType'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? '',
      contentPreview: json['contentPreview'] as String?,
      occurredAt: json['occurredAt'] as String?,
      placeName: json['placeName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((item) => PostAttachment.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  PostSummary copyWith({
    String? contentPreview,
    int? commentCount,
    List<PostAttachment>? attachments,
  }) {
    return PostSummary(
      id: id,
      tripId: tripId,
      transactionId: transactionId,
      authorParticipantId: authorParticipantId,
      authorDisplayName: authorDisplayName,
      postType: postType,
      title: title,
      category: category,
      contentPreview: contentPreview ?? this.contentPreview,
      occurredAt: occurredAt,
      placeName: placeName,
      latitude: latitude,
      longitude: longitude,
      commentCount: commentCount ?? this.commentCount,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class PostDetail {
  final int id;
  final int tripId;
  final int? transactionId;
  final int authorParticipantId;
  final String authorDisplayName;
  final String postType;
  final String title;
  final String category;
  final String? content;
  final String? occurredAt;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int commentCount;
  final List<PostAttachment> attachments;
  final String? createdAt;
  final String? updatedAt;

  const PostDetail({
    required this.id,
    required this.tripId,
    required this.transactionId,
    required this.authorParticipantId,
    required this.authorDisplayName,
    required this.postType,
    required this.title,
    required this.category,
    required this.content,
    required this.occurredAt,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.commentCount,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostDetail.fromJson(Map<String, dynamic> json) {
    return PostDetail(
      id: (json['id'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      transactionId: (json['transactionId'] as num?)?.toInt(),
      authorParticipantId: (json['authorParticipantId'] as num).toInt(),
      authorDisplayName: json['authorDisplayName'] as String? ?? '',
      postType: json['postType'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? '',
      content: json['content'] as String?,
      occurredAt: json['occurredAt'] as String?,
      placeName: json['placeName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((item) => PostAttachment.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  PostSummary toSummary() {
    return PostSummary(
      id: id,
      tripId: tripId,
      transactionId: transactionId,
      authorParticipantId: authorParticipantId,
      authorDisplayName: authorDisplayName,
      postType: postType,
      title: title,
      category: category,
      contentPreview: content,
      occurredAt: occurredAt,
      placeName: placeName,
      latitude: latitude,
      longitude: longitude,
      commentCount: commentCount,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class PostAttachment {
  final int? id;
  final String attachmentType;
  final String fileUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String? mimeType;
  final int sortOrder;

  const PostAttachment({
    required this.id,
    required this.attachmentType,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.fileSize,
    required this.mimeType,
    required this.sortOrder,
  });

  factory PostAttachment.fromJson(Map<String, dynamic> json) {
    return PostAttachment(
      id: (json['id'] as num?)?.toInt(),
      attachmentType: json['attachmentType'] as String? ?? 'IMAGE',
      fileUrl: json['fileUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class PostFormInput {
  final int? transactionId;
  final String title;
  final String category;
  final String? content;
  final String postType;
  final String occurredAt;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final List<PostFileInput> files;
  final bool replaceAttachments;

  const PostFormInput({
    required this.transactionId,
    required this.title,
    required this.category,
    required this.content,
    required this.postType,
    required this.occurredAt,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.files = const [],
    this.replaceAttachments = false,
  });

  Map<String, String> toCreateFields() {
    final fields = _baseFields();
    if (transactionId != null) {
      fields['transactionId'] = transactionId.toString();
    }
    fields['postType'] = postType;
    return fields;
  }

  Map<String, String> toUpdateFields() {
    return {
      ..._baseFields(),
      'replaceAttachments': replaceAttachments.toString(),
    };
  }

  List<MultipartFileInput> toMultipartFiles() {
    return files
        .map(
          (file) => MultipartFileInput(
            fieldName: 'files',
            path: file.path,
            filename: file.filename,
            mimeType: file.mimeType,
          ),
        )
        .toList();
  }

  Map<String, String> _baseFields() {
    return {
      'title': title,
      'category': category,
      'content': content ?? '',
      'occurredAt': occurredAt,
      'placeName': placeName ?? '',
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };
  }
}

class PostFileInput {
  final String path;
  final String filename;
  final String? mimeType;

  const PostFileInput({
    required this.path,
    required this.filename,
    required this.mimeType,
  });
}

class PostCommentListPage {
  final List<PostComment> items;
  final int size;
  final String? nextCursor;
  final bool hasNext;

  const PostCommentListPage({
    required this.items,
    required this.size,
    required this.nextCursor,
    required this.hasNext,
  });

  factory PostCommentListPage.fromJson(Map<String, dynamic> json) {
    return PostCommentListPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => PostComment.fromJson(item as Map<String, dynamic>))
          .toList(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}

class PostComment {
  final int id;
  final int postId;
  final int authorParticipantId;
  final String authorDisplayName;
  final String content;
  final int commentDepth;
  final String? createdAt;
  final String? updatedAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.authorParticipantId,
    required this.authorDisplayName,
    required this.content,
    required this.commentDepth,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: (json['id'] as num).toInt(),
      postId: (json['postId'] as num).toInt(),
      authorParticipantId: (json['authorParticipantId'] as num).toInt(),
      authorDisplayName: json['authorDisplayName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      commentDepth: (json['commentDepth'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
