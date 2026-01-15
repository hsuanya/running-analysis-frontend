import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/feature/upload/upload_controller.dart';
import 'package:frontend/feature/upload/upload_provider.dart';
import 'package:frontend/feature/upload/widget/upload_all_controller.dart';
import 'package:frontend/feature/upload/widget/date_time_selection_widget.dart';
import 'package:frontend/utils/router.dart';
import 'package:frontend/widget/loading_icon.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:frontend/feature/upload/widget/upload_form_provider.dart';

class UploadAllView extends ConsumerStatefulWidget {
  const UploadAllView({super.key});

  @override
  ConsumerState<UploadAllView> createState() => _UploadAllViewState();
}

class _UploadAllViewState extends ConsumerState<UploadAllView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadAllControllerProvider);
    final runnerId = ref.watch(uploadSelectedRunnerIdProvider);
    final formData = ref.watch(uploadAllFormProvider);
    final formNotifier = ref.read(uploadAllFormProvider.notifier);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          spacing: 16,
          children: [
            DateTimeSelectionWidget(
              onDateSelected: (date) {
                formNotifier.state = formData.copyWith(selectedDate: date);
              },
              onTimeSelected: (time) {
                formNotifier.state = formData.copyWith(selectedTime: time);
              },
              onCameraCountSelected: (cameraCount) {
                ref
                    .read(uploadAllControllerProvider.notifier)
                    .setCameraCount(cameraCount);
              },
              onFpsSelected: (fps) {
                formNotifier.state = formData.copyWith(fps: fps);
              },
              onNoteSelected: (note) {
                formNotifier.state = formData.copyWith(note: note);
              },
              selectedDate: formData.selectedDate,
              selectedTime: formData.selectedTime,
              selectedCameraCount: state.cameraCount,
              selectedFps: formData.fps,
              note: formData.note,
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                int columns;
                if (width > 1100) {
                  columns = 3;
                } else if (width > 600) {
                  columns = 2;
                } else {
                  columns = 1;
                }
                final spacing = 12.0;
                final itemWidth = (width - spacing * (columns - 1)) / columns;
                final itemHeight = itemWidth * 9 / 16;

                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List.generate(state.cameraCount, (index) {
                    return GestureDetector(
                      onTap: state.tempVideoStates[index].isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.video,
                                    withData: true,
                                  );

                              if (result == null) return;

                              final file = result.files.first;

                              final uploadFile = UploadVideoFile(
                                bytes: file.bytes!,
                                filename: file.name,
                                mimeType:
                                    lookupMimeType(file.name) ?? 'video/mp4',
                              );

                              await ref
                                  .read(uploadAllControllerProvider.notifier)
                                  .uploadVideo(index, uploadFile);
                            },
                      child: SizedBox(
                        width: itemWidth,
                        height: itemHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: state.tempVideoStates[index].isUploading
                              ? const LoadingIcon()
                              : state.tempVideoStates[index].thumbnailUrl !=
                                    null
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Image.network(
                                      state
                                          .tempVideoStates[index]
                                          .thumbnailUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    '相機${index + 1}\n點擊上傳',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'NotoSansTC',
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Theme.of(context).primaryColor,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'NotoSansTC',
                ),
                padding: const EdgeInsets.symmetric(horizontal: 48),
              ),
              onPressed: () async {
                if (runnerId == null) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('錯誤'),
                        content: const Text('請選擇跑者'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('確定'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
                if (state.tempVideoStates.any((e) => e.thumbnailUrl == null)) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('錯誤'),
                        content: const Text('請上傳所有視頻'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('確定'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                final videoId = await ref
                    .read(uploadControllerProvider.notifier)
                    .uploadAllInfo(
                      runnerId,
                      formData.selectedDate,
                      formData.selectedTime,
                      state.cameraCount,
                      formData.fps,
                      formData.note,
                      state.tempVideoStates.map((e) => e.tempVideoId!).toList(),
                    );

                if (mounted && videoId != null) {
                  // Invalidate history to ensure we fetch the latest list
                  ref.invalidate(runnerHistoryProvider(runnerId));

                  if (mounted) {
                    context.goNamed(
                      AppRoute.playback.name,
                      queryParameters: {
                        'runnerId': runnerId,
                        'videoId': videoId,
                      },
                    );
                  }
                }
              },
              child: const Text('上傳'),
            ),
          ],
        ),
      ],
    );
  }
}
