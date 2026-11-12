import 'dart:convert';
import 'dart:io';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/record/record_state.dart';

class QueueStorageHelper {
  static void setBeforeUnloadProtection(bool hasPending) {}

  static Future<Directory> _getQueueDir() async {
    // 在 iOS / macOS App Sandbox 中，systemTemp 的上層即為 Sandbox 根目錄，
    // 優先存入 <Sandbox>/Documents/running_analysis_upload_queue，避免被系統清理暫存檔機制清除
    try {
      final sandboxDocs = Directory('${Directory.systemTemp.parent.path}/Documents');
      if (await sandboxDocs.exists()) {
        final persistentDir = Directory('${sandboxDocs.path}/running_analysis_upload_queue');
        if (!await persistentDir.exists()) {
          await persistentDir.create(recursive: true);
        }
        return persistentDir;
      }
    } catch (_) {}

    final fallbackDir = Directory('${Directory.systemTemp.path}/running_analysis_upload_queue');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  static Future<void> saveItem(PendingVideoUploadItem item) async {
    try {
      final dir = await _getQueueDir();
      final metaFile = File('${dir.path}/${item.id}.json');
      final binFile = File('${dir.path}/${item.id}_${item.filename}');
      await binFile.writeAsBytes(item.bytes);
      await metaFile.writeAsString(
        jsonEncode({
          'id': item.id,
          'filename': item.filename,
          'binPath': binFile.path,
          'mimeType': item.mimeType,
          'status': item.status.name,
          'errorMessage': item.errorMessage,
          'snapshot': item.snapshot.toJson(),
        }),
      );
    } catch (_) {}
  }

  static Future<void> deleteItem(String id) async {
    try {
      final dir = await _getQueueDir();
      final metaFile = File('${dir.path}/$id.json');
      if (await metaFile.exists()) {
        try {
          final metaMap = Map<String, dynamic>.from(
            jsonDecode(await metaFile.readAsString()) as Map,
          );
          final binPath = metaMap['binPath'] as String?;
          if (binPath != null) {
            final binFile = File(binPath);
            if (await binFile.exists()) await binFile.delete();
          }
        } catch (_) {}
        await metaFile.delete();
      }
      final legacyBin = File('${dir.path}/$id.bin');
      if (await legacyBin.exists()) await legacyBin.delete();
    } catch (_) {}
  }

  static Future<List<PendingVideoUploadItem>> loadAllItems() async {
    try {
      final dir = await _getQueueDir();
      final entities = await dir.list().toList();
      final List<PendingVideoUploadItem> items = [];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          final id = entity.uri.pathSegments.last.replaceAll('.json', '');
          final metaMap = Map<String, dynamic>.from(
            jsonDecode(await entity.readAsString()) as Map,
          );
          final binPath = (metaMap['binPath'] as String?) ?? '${dir.path}/$id.bin';
          final binFile = File(binPath);
          if (!await binFile.exists()) continue;
          final bytes = await binFile.readAsBytes();
          final snap = RecordingMetadataSnapshot.fromJson(
            Map<String, dynamic>.from(metaMap['snapshot'] as Map),
          );
          final statusStr = (metaMap['status'] ?? 'queued').toString();
          var status = PendingUploadStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => PendingUploadStatus.queued,
          );
          if (status == PendingUploadStatus.uploading) {
            status = PendingUploadStatus.queued;
          }
          items.add(
            PendingVideoUploadItem(
              id: id,
              snapshot: snap,
              bytes: bytes,
              filename: (metaMap['filename'] ?? 'video.mp4').toString(),
              mimeType: (metaMap['mimeType'] ?? 'video/mp4').toString(),
              status: status,
              errorMessage: metaMap['errorMessage'] as String?,
            ),
          );
        }
      }
      return items;
    } catch (_) {
      return const [];
    }
  }
}
