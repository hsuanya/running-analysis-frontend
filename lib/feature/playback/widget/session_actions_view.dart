import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/run_session_info.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/feature/playback/widget/delete_session_dialog.dart';
import 'package:frontend/utils/locale_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/utils/download_helper/download_helper.dart';

class SessionActionsView extends ConsumerWidget {
  const SessionActionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final runnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);

    if (runnerId == null || videoId == null) {
      return _buildActionsContent(
        context,
        l10n: l10n,
        isDownloadEnabled: false,
        isDeleteEnabled: false,
      );
    }

    final videoInfo = ref.watch(videoInfoProvider(videoId));
    return AsyncValueWidget(
      value: videoInfo,
      loading: _buildActionsContent(
        context,
        l10n: l10n,
        isDownloadEnabled: false,
        isDeleteEnabled: false,
      ),
      data: (RunSessionInfo video) {
        final isDone = video.status == 'done';
        final isFailed = video.status == 'failed';

        return _buildActionsContent(
          context,
          l10n: l10n,
          isDownloadEnabled: isDone,
          isDeleteEnabled: isDone || isFailed,
          onPdf: () async {
            final filename = "Runner_Analysis_Report_${video.runSessionId}.pdf";
            final backend = ref.read(backendProvider);
            final bytes = await backend.getRunSessionPdf(video.runSessionId);
            await saveBytesToFile(bytes, filename);
          },
          onCsv: () async {
            final filename = "angles_${video.runSessionId}.csv";
            final backend = ref.read(backendProvider);
            final bytes = await backend.getRunSessionCsv(video.runSessionId);
            await saveBytesToFile(bytes, filename);
          },
          onDelete: () => showDeleteRunSessionDialog(
            context: context,
            ref: ref,
            runSessionId: video.runSessionId,
            runnerId: video.runnerId,
          ),
        );
      },
    );
  }

  Widget _buildActionsContent(
    BuildContext context, {
    required dynamic l10n,
    required bool isDownloadEnabled,
    required bool isDeleteEnabled,
    VoidCallback? onPdf,
    VoidCallback? onCsv,
    VoidCallback? onDelete,
  }) {
    final pdfButton = ElevatedButton.icon(
      onPressed: isDownloadEnabled ? onPdf : null,
      icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
      label: Text(
        l10n.downloadPdfReport,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 121, 169, 234),
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final csvButton = ElevatedButton.icon(
      onPressed: isDownloadEnabled ? onCsv : null,
      icon: const Icon(Icons.table_chart, color: Colors.white, size: 18),
      label: Text(
        l10n.downloadCsvData,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal[400],
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final deleteButton = ElevatedButton.icon(
      onPressed: isDeleteEnabled ? onDelete : null,
      icon: const Icon(Icons.delete, color: Colors.white, size: 18),
      label: Text(
        l10n.deleteSessionConfirmTitle,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Center(
            child: Text(
              l10n.actions,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Divider(color: Colors.white, thickness: 3.0, height: 3.0),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 400;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompact) ...[
                    pdfButton,
                    const SizedBox(height: 12),
                    csvButton,
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: pdfButton),
                        const SizedBox(width: 12),
                        Expanded(child: csvButton),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  deleteButton,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
