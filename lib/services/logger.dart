import 'dart:convert';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static void _log(LogLevel level, String tag, String message, {Object? error, StackTrace? stack}) {
    final levelStr = level.name.toUpperCase().padRight(7);
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final buffer = StringBuffer('[$ts] $levelStr [$tag] $message');
    if (error != null) buffer.write('\n  ↳ Error: $error');
    if (stack != null) {
      final stackStr = stack.toString().split('\n').take(8).join('\n  ');
      buffer.write('\n  ↳ Stack:\n  $stackStr');
    }
    debugPrint(buffer.toString());
  }

  // ── API ──
  static void apiRequest(String method, String url, {dynamic body}) {
    final bodyStr = body != null ? '\n  Body: ${_safeJson(body)}' : '';
    _log(LogLevel.info, 'API', '→ $method $url$bodyStr');
  }

  static void apiResponse(String method, String url, int statusCode, dynamic body) {
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.info;
    final bodyStr = body != null ? '\n  Body: ${_safeJson(body)}' : '';
    _log(level, 'API', '← $method $url [$statusCode]$bodyStr');
  }

  static void apiError(String method, String url, Object error, {StackTrace? stack}) {
    _log(LogLevel.error, 'API', '✗ $method $url failed', error: error, stack: stack);
  }

  // ── App ──
  static void info(String tag, String message) => _log(LogLevel.info, tag, message);
  static void warning(String tag, String message) => _log(LogLevel.warning, tag, message);

  static void error(String tag, String message, {Object? error, StackTrace? stack}) {
    _log(LogLevel.error, tag, message, error: error, stack: stack);
  }

  static void catchBlock(String tag, String context, Object error, StackTrace stack) {
    _log(LogLevel.error, tag, '$context failed', error: error, stack: stack);
  }

  static String _safeJson(dynamic data) {
    try {
      final encoded = jsonEncode(data);
      return encoded.length > 500 ? '${encoded.substring(0, 500)}... (truncated)' : encoded;
    } catch (_) {
      return data.toString();
    }
  }
}
