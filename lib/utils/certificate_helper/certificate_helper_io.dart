import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void allowSelfSignedCertificates(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..badCertificateCallback = (cert, host, port) => true,
  );
}
