import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri) {
  return WebSocketChannel.connect(uri);
}
