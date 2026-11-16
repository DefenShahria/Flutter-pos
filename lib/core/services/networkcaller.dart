import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'networkresponse.dart';
import '../constants/urls.dart';

class NetworkCaller {
  NetworkCaller._internal();

  static final NetworkCaller instance = NetworkCaller._internal();

  late final Dio _defaultDio;
  late final Dio _uploadDio;
  late final Dio _downloadDio;
  String? _authToken;
  void Function()? _onUnauthorized;
  bool _initialized = false;

  void setAuthToken(String token) {
    _authToken = token;
    _updateInterceptors();
  }

  void setOnUnauthorized(void Function()? callback) {
    _onUnauthorized = callback;
  }

  String? get authToken => _authToken;

  void _attachAuth(RequestOptions options) {
    if (_authToken != null &&
        _authToken!.isNotEmpty &&
        options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $_authToken';
    }
  }

  void _updateInterceptors() {
    void install(Dio dio) {
      dio.interceptors.clear();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          _attachAuth(options);
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401 && _onUnauthorized != null) {
            _onUnauthorized!();
          }
          return handler.next(e);
        },
      ));
    }

    install(_defaultDio);
    install(_uploadDio);
    install(_downloadDio);
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    _defaultDio = Dio(BaseOptions(
      baseUrl: Urls.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 3),
    ));

    _uploadDio = Dio(BaseOptions(
      baseUrl: Urls.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: null,
      sendTimeout: null,
    ));

    _downloadDio = Dio(BaseOptions(
      baseUrl: Urls.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: null,
    ));

    _updateInterceptors();
  }

  Future<NetworkResponse> postFormRequest({
    required String path,
    required Map<String, String> fields,
  }) async {
    try {
      final resp = await _defaultDio.post(
        path,
        data: FormData.fromMap(fields),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return NetworkResponse.ok(resp.data, statusCode: resp.statusCode ?? 0);
    } on DioException catch (e) {
      return NetworkResponse.error(
        message: mapDioError(e),
        statusCode: e.response?.statusCode ?? 0,
      );
    } catch (e) {
      return NetworkResponse.error(message: 'Unexpected error: $e');
    }
  }

  Future<NetworkResponse> getRequest(String path) async {
    try {
      final resp = await _defaultDio.get(path);
      return NetworkResponse.ok(resp.data, statusCode: resp.statusCode ?? 0);
    } on DioException catch (e) {
      return NetworkResponse.error(
        message: mapDioError(e),
        statusCode: e.response?.statusCode ?? 0,
      );
    } catch (e) {
      return NetworkResponse.error(message: 'Unexpected error: $e');
    }
  }

  Future<NetworkResponse> deleteRequest(String path) async {
    try {
      final resp = await _defaultDio.delete(path);
      return NetworkResponse.ok(resp.data, statusCode: resp.statusCode ?? 0);
    } on DioException catch (e) {
      return NetworkResponse.error(
        message: mapDioError(e),
        statusCode: e.response?.statusCode ?? 0,
      );
    } catch (e) {
      return NetworkResponse.error(message: 'Unexpected error: $e');
    }
  }

  Future<NetworkResponse> uploadFile({
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final resp = await _uploadDio.post(
        '/upload',
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          receiveTimeout: null,
          sendTimeout: null,
        ),
      );
      return NetworkResponse.ok(resp.data, statusCode: resp.statusCode ?? 0);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return NetworkResponse.error(message: 'Upload was cancelled.');
      }
      return NetworkResponse.error(
        message: mapDioError(e),
        statusCode: e.response?.statusCode ?? 0,
      );
    } catch (e) {
      return NetworkResponse.error(message: 'Unexpected error: $e');
    }
  }

  // Stream-based download with Range support for resumable downloads.
  // On 200 when resuming (server ignores Range), the partial file is deleted
  // and the caller must restart.
  Future<NetworkResponse> downloadFile({
    required String url,
    required String savePath,
    required void Function(int received, int total) onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? extraHeaders,
    int resumeFrom = 0,
  }) async {
    try {
      final parentDir =
          Directory(savePath.substring(0, savePath.lastIndexOf('/')));
      if (!parentDir.existsSync()) await parentDir.create(recursive: true);

      final file = File(savePath);
      final isResume = resumeFrom > 0 && file.existsSync();
      final fileStream =
          file.openWrite(mode: isResume ? FileMode.append : FileMode.write);

      try {
        final response = await _downloadDio.get(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: extraHeaders,
            receiveTimeout: null,
          ),
          cancelToken: cancelToken,
        );

        final statusCode = response.statusCode ?? 0;
        final contentLengthHeader =
            response.data?.headers.value('content-length');
        final totalBytes = int.tryParse(contentLengthHeader ?? '') ?? 0;

        // Server returned 200 when we expected 206 — resume not supported.
        if (isResume && statusCode == 200) {
          await fileStream.close();
          await file.delete();
          return NetworkResponse.error(
            message: 'Server does not support resume. Restarting from scratch.',
            statusCode: 200,
          );
        }

        final bytesStream = response.data!.stream;
        int received = 0;
        await for (final chunk in bytesStream) {
          if (cancelToken != null && cancelToken.isCancelled) break;
          fileStream.write(chunk);
          received += chunk.length as int;
          final int overallReceived = (isResume ? resumeFrom : 0) + received;
          final int overallTotal = totalBytes > 0
              ? (isResume ? resumeFrom + totalBytes : totalBytes)
              : overallReceived;
          onReceiveProgress(overallReceived, overallTotal);
        }
        await fileStream.close();

        if (cancelToken != null && cancelToken.isCancelled) {
          return NetworkResponse.error(message: 'Download was cancelled.');
        }

        return NetworkResponse.ok(null, statusCode: statusCode);
      } catch (e) {
        await fileStream.close();
        rethrow;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return NetworkResponse.error(message: 'Download was cancelled.');
      }
      return NetworkResponse.error(
        message: mapDioError(e),
        statusCode: e.response?.statusCode ?? 0,
      );
    } catch (e) {
      return NetworkResponse.error(message: 'Unexpected error: $e');
    }
  }
}
