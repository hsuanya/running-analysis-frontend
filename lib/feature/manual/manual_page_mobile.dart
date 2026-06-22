import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget buildWebView(String url) => const SizedBox.shrink();

Widget buildMobileView(String url) {
  return _MobileWebView(url: url);
}

class _MobileWebView extends StatefulWidget {
  final String url;
  const _MobileWebView({required this.url});

  @override
  State<_MobileWebView> createState() => _MobileWebViewState();
}

class _MobileWebViewState extends State<_MobileWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
