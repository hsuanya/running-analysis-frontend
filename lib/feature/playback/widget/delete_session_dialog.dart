import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/utils/locale_provider.dart';

Future<bool> showDeleteRunSessionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String runSessionId,
  required String runnerId,
}) async {
  final l10n = context.l10n;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteSessionConfirmTitle),
      content: Text(l10n.deleteSessionConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );

  if (confirm == true) {
    if (!context.mounted) return false;
    try {
      final backend = ref.read(backendProvider);

      // 1. 取得刪除前的清單與當前項目的索引
      final prevHistory = await backend.getRunnerHistory(runnerId);
      final deletedIndex = prevHistory.indexWhere((s) => s.runSessionId == runSessionId);

      // 2. 執行刪除
      await backend.deleteRunSession(runSessionId);

      // 3. 取得刪除後的剩餘紀錄清單
      final remainingHistory = await backend.getRunnerHistory(runnerId);

      // 4. 計算應跳轉的下一筆紀錄（跳至原本這筆相鄰的上一筆／下一筆紀錄）
      String? nextSelectedId;
      if (remainingHistory.isNotEmpty) {
        if (deletedIndex >= 0 && deletedIndex < remainingHistory.length) {
          nextSelectedId = remainingHistory[deletedIndex].runSessionId;
        } else {
          nextSelectedId = remainingHistory.last.runSessionId;
        }
      }

      final currentSelected = ref.read(playbackSelectedRunSessionIdProvider);
      if (currentSelected == runSessionId) {
        ref.read(playbackSelectedRunSessionIdProvider.notifier).state = nextSelectedId;
      }

      ref.invalidate(runnerHistoryProvider(runnerId));
      ref.invalidate(runnerProvider);
      ref.invalidate(videoInfoProvider(runSessionId));
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      return false;
    }
  }
  return false;
}
