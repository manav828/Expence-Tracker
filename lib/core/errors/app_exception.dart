/// Standardized exception hierarchy for ExpenCircle.
abstract class AppException implements Exception {
  final String message;
  final String? technicalDetails;
  final int? statusCode;

  const AppException(
    this.message, {
    this.technicalDetails,
    this.statusCode,
  });

  @override
  String toString() => 'AppException: $message ${technicalDetails != null ? '($technicalDetails)' : ''}';
}

/// Network connectivity or timeout failure
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection issue. Please check your internet connection.',
    String? details,
  ]) : super(technicalDetails: details);
}

/// API or HTTP request error with status code
class ApiException extends AppException {
  const ApiException(
    super.message, {
    super.statusCode,
    super.technicalDetails,
  });
}

/// Authentication and session failures
class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.technicalDetails,
  });
}

/// Data validation errors
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.technicalDetails,
  });
}

/// Local database or cloud storage failures
class StorageException extends AppException {
  const StorageException(
    super.message, {
    super.technicalDetails,
  });
}
