// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadFileFromUrl(String url, String filename) {
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..target = '_blank'
    ..click();
}

Future<void> saveBytesToFile(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
