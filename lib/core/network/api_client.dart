import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_response.dart';

/// Scalable, resilient HTTP Client for ExpenCircle API integrations.
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final ApiClient instance = ApiClient();

  /// Executes an HTTP GET request with standard headers, timeout, and error translation.
  Future<ApiResponse<Map<String, dynamic>>> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: AppConfig.apiTimeoutSeconds),
  }) async {
    try {
      final response = await _client
          .get(uri, headers: _buildHeaders(headers))
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.failure('Unable to connect to server', statusCode: 0);
    } on TimeoutException {
      return ApiResponse.failure('Request timed out', statusCode: 408);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  /// Executes an HTTP POST request.
  Future<ApiResponse<Map<String, dynamic>>> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: AppConfig.apiTimeoutSeconds),
  }) async {
    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(headers),
            body: body is Map ? jsonEncode(body) : body,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.failure('Unable to connect to server', statusCode: 0);
    } on TimeoutException {
      return ApiResponse.failure('Request timed out', statusCode: 408);
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  Map<String, String> _buildHeaders(Map<String, String>? custom) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (custom != null) ...custom,
    };
  }

  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return ApiResponse.success({}, statusCode: status);
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return ApiResponse.success(decoded, statusCode: status);
        } else if (decoded is List) {
          return ApiResponse.success({'data': decoded}, statusCode: status);
        }
        return ApiResponse.success({'result': decoded}, statusCode: status);
      } catch (e) {
        return ApiResponse.failure('Invalid JSON response format', statusCode: status);
      }
    } else {
      String message = 'HTTP Error $status';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      return ApiResponse.failure(message, statusCode: status);
    }
  }

  void close() {
    _client.close();
  }
}
