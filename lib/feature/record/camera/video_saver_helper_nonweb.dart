import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class VideoSaverHelper {
  static Future<bool> saveVideo({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        fileName: filename,
        bytes: bytes,
      );
      if (savedPath == null) return false;
      final file = File(savedPath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

