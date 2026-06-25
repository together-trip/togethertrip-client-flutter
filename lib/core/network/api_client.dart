import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../env/env.dart';

const _baseUrl = Env.apiBaseUrl;

String resolveApiUrl(String value) {
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  if (_baseUrl.isEmpty) return value;
  return Uri.parse(_baseUrl).resolve(value).toString();
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? queryParameters,
    String? accessToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final headers = {'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _client.get(url, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? queryParameters,
    String? accessToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final headers = {'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _client.get(url, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return const [];
    final data = decoded['data'];
    if (data is List<dynamic>) return data;
    throw FormatException('응답 data가 배열이 아닙니다.', decoded);
  }

  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> patch(
    String path,
    Map<String, dynamic> body, {
    required String accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _client.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> multipart(
    String method,
    String path, {
    required Map<String, String> fields,
    required List<MultipartFileInput> files,
    required String accessToken,
  }) async {
    final request = http.MultipartRequest(method, Uri.parse('$_baseUrl$path'));
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields.addAll(fields);

    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath(
          file.fieldName,
          file.path,
          filename: file.filename,
          contentType: file.mimeType == null
              ? null
              : MediaType.parse(file.mimeType!),
        ),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> put(
    String path,
    Map<String, dynamic> body, {
    required String accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _client.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> delete(
    String path, {
    required String accessToken,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _client.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: body == null ? null : jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response),
      );
    }

    final decoded = _decodeResponseBody(response.body);
    if (decoded == null) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}

Map<String, dynamic>? _decodeResponseBody(String body) {
  if (body.trim().isEmpty) return null;

  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);

  throw FormatException('응답 body가 JSON 객체가 아닙니다.', decoded);
}

String _errorMessage(http.Response response) {
  if (response.body.trim().isEmpty) return '서버 오류가 발생했습니다.';

  try {
    final decoded = _decodeResponseBody(response.body);
    return decoded?['message']?.toString() ?? '서버 오류가 발생했습니다.';
  } on FormatException {
    return '서버 오류가 발생했습니다.';
  }
}

class MultipartFileInput {
  final String fieldName;
  final String path;
  final String? filename;
  final String? mimeType;

  const MultipartFileInput({
    required this.fieldName,
    required this.path,
    this.filename,
    this.mimeType,
  });
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
