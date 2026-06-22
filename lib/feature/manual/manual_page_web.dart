// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

bool _registered = false;

Widget buildWebView(String path) {
  const viewType = 'manual-iframe';
  // document.baseURI 會是 http://host/running_analysis/
  // 加上 docs/user_manual.html 得到完整路徑
  final base = html.document.baseUri ?? '';
  final url = base.endsWith('/') ? '$base$path' : '$base/$path';

  if (!_registered) {
    _registered = true;
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }
  return const HtmlElementView(viewType: viewType);
}

Widget buildMobileView(String url) => const SizedBox.shrink();
