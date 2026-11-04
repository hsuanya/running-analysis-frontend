import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:mime/mime.dart';

class VideoPickerHelper {
  /// Entry point for picking a video file.
  /// Uses FileType.video so that:
  /// - On iOS Safari: The native menu directly provides "照片圖庫" (Photo Library)
  ///   and "選擇檔案" (Files) in a single tap, without requiring a redundant Flutter popup.
  /// - On Android / Desktop: Automatically filters to video formats.
  static Future<UploadVideoFile?> pickVideo(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.bytes == null) return null;

    String filename = file.name;
    if (!filename.contains('.')) {
      filename = '$filename.mp4';
    }

    final mimeType = lookupMimeType(filename) ?? 'video/mp4';

    return UploadVideoFile(
      bytes: file.bytes!,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
