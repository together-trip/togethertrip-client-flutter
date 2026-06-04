import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = String.fromEnvironment('API_BASE_URL');

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

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: decoded['message']?.toString() ?? '서버 오류가 발생했습니다.',
      );
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
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

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: decoded['message']?.toString() ?? '서버 오류가 발생했습니다.',
      );
    }

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

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: decoded['message']?.toString() ?? '서버 오류가 발생했습니다.',
      );
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> delete(
    String path, {
    required String accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await _client.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.isEmpty
          ? '서버 오류가 발생했습니다.'
          : (jsonDecode(response.body) as Map<String, dynamic>)['message']
                    ?.toString() ??
                '서버 오류가 발생했습니다.';
      throw ApiException(statusCode: response.statusCode, message: message);
    }

    if (response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
