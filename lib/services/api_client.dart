import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

class ApiClient {
  static bool _isOffline = false;
  static final ValueNotifier<bool> isConnectingLong = ValueNotifier<bool>(false);

  static const Duration requestTimeout = Duration(seconds: 45);
  static const int maxRetries = 2;

  static void setOffline(bool value) => _isOffline = value;
  static bool get isOffline => _isOffline;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> _executeWithRetry(
    String method,
    String url,
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    Timer? connectingTimer;
    // แจ้งเตือน UI หากการเชื่อมต่อใช้เวลานานกว่า 3 วินาที (เช่น เซิร์ฟเวอร์กำลัง Cold Start)
    connectingTimer = Timer(const Duration(seconds: 3), () {
      isConnectingLong.value = true;
    });

    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final headers = await _getHeaders();
        final response = await requestFn(headers).timeout(requestTimeout);

        // หากได้ status 502/503/504 ช่วงที่ Render กำลังปลุก และยังมีโควต้า retry ให้ลองยิงใหม่
        if ((response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) &&
            attempts <= maxRetries) {
          Logger.info('ApiClient', '$method $url returned status ${response.statusCode}, retrying ($attempts/$maxRetries)...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        connectingTimer.cancel();
        isConnectingLong.value = false;
        return response;
      } catch (e, st) {
        if ((e is TimeoutException || e.toString().contains('Timeout')) && attempts <= maxRetries) {
          Logger.info('ApiClient', '$method $url timed out, retrying ($attempts/$maxRetries)...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        connectingTimer.cancel();
        isConnectingLong.value = false;
        Logger.apiError(method, url, e, stack: st);
        rethrow;
      }
    }
  }

  static Future<dynamic> get(String url) async {
    if (_isOffline) return null;
    final method = 'GET';
    Logger.apiRequest(method, url);
    try {
      final response = await _executeWithRetry(
        method,
        url,
        (headers) => http.get(Uri.parse(url), headers: headers),
      );
      Logger.apiResponse(method, url, response.statusCode, _tryDecodeBody(response.body));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _tryDecodeBody(response.body);
      } else {
        throw Exception('Server Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> post(String url, dynamic data) async {
    if (_isOffline) return null;
    final method = 'POST';
    Logger.apiRequest(method, url, body: data);
    try {
      final response = await _executeWithRetry(
        method,
        url,
        (headers) => http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        ),
      );
      Logger.apiResponse(method, url, response.statusCode, _tryDecodeBody(response.body));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _tryDecodeBody(response.body);
      } else {
        throw Exception('Server Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> put(String url, dynamic data) async {
    if (_isOffline) return null;
    final method = 'PUT';
    Logger.apiRequest(method, url, body: data);
    try {
      final response = await _executeWithRetry(
        method,
        url,
        (headers) => http.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        ),
      );
      Logger.apiResponse(method, url, response.statusCode, _tryDecodeBody(response.body));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _tryDecodeBody(response.body);
      } else {
        throw Exception('Server Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> delete(String url) async {
    if (_isOffline) return null;
    final method = 'DELETE';
    Logger.apiRequest(method, url);
    try {
      final response = await _executeWithRetry(
        method,
        url,
        (headers) => http.delete(Uri.parse(url), headers: headers),
      );
      Logger.apiResponse(method, url, response.statusCode, _tryDecodeBody(response.body));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _tryDecodeBody(response.body);
      } else {
        throw Exception('Server Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static dynamic _tryDecodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return body;
    }
  }
}

