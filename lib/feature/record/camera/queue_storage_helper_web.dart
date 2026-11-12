// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:typed_data';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/record/record_state.dart';

class QueueStorageHelper {
  static const String _dbName = 'running_analysis_upload_queue_db';
  static const String _storeName = 'pending_uploads';
  static idb.Database? _db;
  static bool _beforeUnloadRegistered = false;
  static bool _hasPendingItems = false;

  static void setBeforeUnloadProtection(bool hasPending) {
    _hasPendingItems = hasPending;
    if (!_beforeUnloadRegistered) {
      _beforeUnloadRegistered = true;
      html.window.onBeforeUnload.listen((event) {
        if (_hasPendingItems && event is html.BeforeUnloadEvent) {
          event.returnValue = '尚有錄影影片正在等待上傳，確定要離開此頁面嗎？';
        }
      });
    }
  }

  static Future<idb.Database?> _getDb() async {
    if (_db != null) return _db;
    final factory = html.window.indexedDB;
    if (factory == null) return null;
    try {
      _db = await factory.open(
        _dbName,
        version: 1,
        onUpgradeNeeded: (idb.VersionChangeEvent event) {
          final db = event.target.result as idb.Database;
          if (!db.objectStoreNames!.contains(_storeName)) {
            db.createObjectStore(_storeName, keyPath: 'id');
          }
        },
      );
      return _db;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveItem(PendingVideoUploadItem item) async {
    try {
      final db = await _getDb();
      if (db == null) return;
      final txn = db.transaction(_storeName, 'readwrite');
      final store = txn.objectStore(_storeName);
      await store.put({
        'id': item.id,
        'filename': item.filename,
        'mimeType': item.mimeType,
        'status': item.status.name,
        'errorMessage': item.errorMessage,
        'snapshotJson': jsonEncode(item.snapshot.toJson()),
        'bytes': item.bytes,
      });
      await txn.completed;
    } catch (_) {}
  }

  static Future<void> deleteItem(String id) async {
    try {
      final db = await _getDb();
      if (db == null) return;
      final txn = db.transaction(_storeName, 'readwrite');
      final store = txn.objectStore(_storeName);
      await store.delete(id);
      await txn.completed;
    } catch (_) {}
  }

  static Future<List<PendingVideoUploadItem>> loadAllItems() async {
    try {
      final db = await _getDb();
      if (db == null) return const [];
      final txn = db.transaction(_storeName, 'readonly');
      final store = txn.objectStore(_storeName);
      final List<PendingVideoUploadItem> items = [];

      await for (final cursor in store.openCursor(autoAdvance: true)) {
        final val = cursor.value;
        if (val is Map) {
          final id = (val['id'] ?? '').toString();
          final filename = (val['filename'] ?? 'video.mp4').toString();
          final mimeType = (val['mimeType'] ?? 'video/mp4').toString();
          final statusStr = (val['status'] ?? 'queued').toString();
          final errorMessage = val['errorMessage'] as String?;
          final snapshotJson = (val['snapshotJson'] ?? '{}').toString();
          final rawBytes = val['bytes'];

          Uint8List? bytes;
          if (rawBytes is Uint8List) {
            bytes = rawBytes;
          } else if (rawBytes is ByteBuffer) {
            bytes = rawBytes.asUint8List();
          } else if (rawBytes is List) {
            bytes = Uint8List.fromList(rawBytes.cast<int>());
          }

          if (id.isNotEmpty && bytes != null && bytes.isNotEmpty) {
            final snapMap = Map<String, dynamic>.from(jsonDecode(snapshotJson) as Map);
            final snapshot = RecordingMetadataSnapshot.fromJson(snapMap);
            var status = PendingUploadStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => PendingUploadStatus.queued,
            );
            // 若重新載入時原本是 uploading，改回 queued 以便接續或手動重試
            if (status == PendingUploadStatus.uploading) {
              status = PendingUploadStatus.queued;
            }
            items.add(
              PendingVideoUploadItem(
                id: id,
                snapshot: snapshot,
                bytes: bytes,
                filename: filename,
                mimeType: mimeType,
                status: status,
                errorMessage: errorMessage,
              ),
            );
          }
        }
      }
      return items;
    } catch (_) {
      return const [];
    }
  }
}

