void downloadFileFromUrl(String url, String filename) {
  throw UnsupportedError('downloadFileFromUrl is only supported on Web');
}

Future<void> saveBytesToFile(List<int> bytes, String filename) async {
  throw UnsupportedError('saveBytesToFile is only supported on mobile/desktop');
}
