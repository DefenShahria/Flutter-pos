import 'package:dio/dio.dart';

class NetworkResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic responseData;
  final String errorMessage;

  const NetworkResponse({
    this.isSuccess = false,
    this.statusCode = 0,
    this.responseData,
    this.errorMessage = '',
  });

  factory NetworkResponse.ok(dynamic data, {int statusCode = 200}) =>
      NetworkResponse(
          isSuccess: true, statusCode: statusCode, responseData: data);

  factory NetworkResponse.error({
    required String message,
    int statusCode = 0,
  }) =>
      NetworkResponse(
        isSuccess: false,
        statusCode: statusCode,
        errorMessage: message,
      );
}

String mapDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timed out. Please check your network and try again.';
    case DioExceptionType.badCertificate:
      return 'Invalid server certificate. Contact support.';
    case DioExceptionType.badResponse:
      switch (error.response?.statusCode) {
        case 401:
          return 'Session expired. Please log in again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'The requested resource was not found.';
        case 413:
          return 'File is too large. Please choose a smaller file.';
        case 414:
          return 'The file name is too long.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server error (${error.response?.statusCode}). Please try again later.';
        default:
          return 'Server error ${error.response?.statusCode ?? "unknown"}. Please try again.';
      }
    case DioExceptionType.cancel:
      return 'Transfer was cancelled.';
    case DioExceptionType.connectionError:
      return 'No internet connection. Check your network settings.';
    case DioExceptionType.unknown:
      if (error.message?.contains('SocketException') ?? false) {
        return 'No internet connection. Please check your network settings.';
      }
      return 'An unknown error occurred. Please try again.';
    case DioExceptionType.transformTimeout:
      return 'The response took too long to process. Please try again.';
  }
}
