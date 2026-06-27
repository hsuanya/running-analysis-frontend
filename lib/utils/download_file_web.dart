// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const supportsFileDownload = true;

void downloadFileFromUrl({required String filename, required Uri url}) {
  final anchor = html.AnchorElement(href: url.toString())
    ..download = filename
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
