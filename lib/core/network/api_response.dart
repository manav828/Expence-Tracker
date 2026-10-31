/// Standard wrapper for HTTP/API responses across the application.
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  const ApiResponse({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {int statusCode = 200}) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure(String errorMessage, {int? statusCode}) {
    return ApiResponse(
      isSuccess: false,
      errorMessage: errorMessage,
      statusCode: statusCode,
    );
  }
}
