import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri) {
  final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
  return IOWebSocketChannel.connect(uri, customClient: client);
}
