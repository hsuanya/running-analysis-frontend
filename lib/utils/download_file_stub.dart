const supportsFileDownload = false;

void downloadFileFromUrl({required String filename, required Uri url}) {
  throw UnsupportedError('File download is only supported on web.');
}
