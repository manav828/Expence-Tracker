import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_exception.dart';

/// Central utility for parsing, sanitizing, and formatting errors for user-facing UI.
class ErrorHandler {
  ErrorHandler._();

  /// Converts any caught error into a clean, friendly message suitable for SnackBars/Dialogs.
  /// Enforces privacy and never leaks internal service names (Supabase, Cloudflare, Pixabay)
  /// or raw SQL/schema exceptions to the end user.
  static String getUserMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is SocketException || error is TimeoutException) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    final errStr = error.toString().toLowerCase();

    // Sensitive service names / technical keywords sanitization
    if (errStr.contains('supabase') ||
        errStr.contains('pgrst') ||
        errStr.contains('schema cache') ||
        errStr.contains('column') ||
        errStr.contains('relation')) {
      return 'A temporary service issue occurred. Please try again shortly.';
    }

    if (errStr.contains('cloudflare') || errStr.contains('r2') || errStr.contains('s3')) {
      return 'Attachment storage is temporarily unavailable. Please try again later.';
    }

    if (errStr.contains('pixabay')) {
      return 'Image search service is currently unavailable.';
    }

    if (errStr.contains('network') || errStr.contains('failed host lookup') || errStr.contains('connection refused')) {
      return 'Network connection lost. Please check your connection.';
    }

    if (errStr.contains('unauthorized') || errStr.contains('jwt') || errStr.contains('token')) {
      return 'Your session has expired. Please log in again.';
    }

    // Default friendly fallback
    return 'Something went wrong. Please try again.';
  }

  /// Safe logging for development without exposing sensitive tokens.
  static void log(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$context] Error: $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[$context] StackTrace: $stackTrace');
    }
  }
}
