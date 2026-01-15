import 'dart:convert';
import 'package:dio/dio.dart';

enum DioMethod { get, post, patch, put, delete }

class NetUtils {
  static NetUtils? _instance;
  late Dio _dio;

  _init() {
    BaseOptions options = BaseOptions(
      connectTimeout: Duration(seconds: 180),
      receiveTimeout: Duration(seconds: 180),
    );

    _dio = Dio(options);

    _dio.options.headers["Access-Control-Allow-Origin"] = "*";
    _dio.options.headers["Access-Control-Allow-Credentials"] = true;
    _dio.options.headers["Access-Control-Allow-Headers"] =
        "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,locale";
    _dio.options.headers["Access-Control-Allow-Methods"] =
        "GET, HEAD, POST, PATCH, OPTIONS";
  }

  NetUtils._internal() {
    _instance = this;
    _init();
  }

  factory NetUtils() => _instance ?? NetUtils._internal();

  Future<T> reqeustData<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic postData,
    String token = '',
    DioMethod method = DioMethod.get,
  }) async {
    try {
      if (token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Token $token';
      }
      _dio.options.headers['ngrok-skip-browser-warning'] = true;

      Response response;
      if (method == DioMethod.get) {
        response = await _dio.get(path, queryParameters: queryParameters);
      } else if (method == DioMethod.post) {
        response = await _dio.post(path, data: postData);
      } else if (method == DioMethod.patch) {
        response = await _dio.patch(path, data: postData);
      } else if (method == DioMethod.put) {
        response = await _dio.put(path, data: postData);
      } else if (method == DioMethod.delete) {
        response = await _dio.delete(path, data: postData);
      } else {
        throw Exception('Unknown DioMethod');
      }

      return response.data as T;
    } on DioException catch (e) {
      // DioError only return error 500
      String message = e.response?.data['message'] ?? e.message;
      if (e.type == DioExceptionType.connectionTimeout) {
        message = "Connection Timeout";
      } else if (e.type == DioExceptionType.receiveTimeout) {
        message = "Receive Timeout";
      }

      return Future.error(message);
    } catch (error) {
      return Future.error(error);
    }
  }

  Stream<String> requestStream(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic postData,
    String token = '',
    DioMethod method = DioMethod.get,
  }) async* {
    try {
      if (token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Token $token';
      }

      Response<ResponseBody> response;
      if (method == DioMethod.get) {
        response = await _dio.get<ResponseBody>(
          path,
          queryParameters: queryParameters,
          options: Options(responseType: ResponseType.stream),
        );
      } else if (method == DioMethod.post) {
        response = await _dio.post<ResponseBody>(
          path,
          data: postData,
          options: Options(responseType: ResponseType.stream),
        );
      } else if (method == DioMethod.patch) {
        response = await _dio.patch<ResponseBody>(
          path,
          data: postData,
          options: Options(responseType: ResponseType.stream),
        );
      } else if (method == DioMethod.put) {
        response = await _dio.put<ResponseBody>(
          path,
          data: postData,
          options: Options(responseType: ResponseType.stream),
        );
      } else if (method == DioMethod.delete) {
        response = await _dio.delete<ResponseBody>(
          path,
          data: postData,
          options: Options(responseType: ResponseType.stream),
        );
      } else {
        throw Exception('Unknown DioMethod');
      }

      final stream = response.data?.stream;

      if (stream != null) {
        // 將 stream 轉換成文字
        await for (var chunk in utf8.decoder.bind(stream)) {
          for (var line in const LineSplitter().convert(chunk)) {
            if (line.startsWith("data:")) {
              final data = line.substring(5).trim();
              if (data.isNotEmpty && data != '[END]') {
                yield data;
              }
            }
          }
        }
      }
    } on DioException catch (e) {
      yield* Stream.error(e.message ?? "Dio error");
    } catch (e) {
      yield* Stream.error(e);
    }
  }
}
