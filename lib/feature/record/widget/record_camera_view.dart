import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/feature/record/record_controller.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/widget/loading_icon.dart';
import 'package:mime/mime.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:shimmer/shimmer.dart';

class RecordCameraView extends ConsumerStatefulWidget {
  const RecordCameraView({super.key});

  @override
  ConsumerState<RecordCameraView> createState() => _RecordCameraViewState();
}

class _RecordCameraViewState extends ConsumerState<RecordCameraView>
    with ChangeNotifier {
  CameraController? _controller;
  bool _isInitialized = false;
  XFile? _recordedFile;
  bool _isUploading = false;
  bool _isShowingFullscreen = false;

  List<CameraDescription> _allBackCameras = [];
  int _currentBackCameraIndex = 0;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      if (kDebugMode) print('正在獲取可用相機...');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (kDebugMode) print('找不到任何相機');
        return;
      }

      // 找出所有後置鏡頭項目
      _allBackCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();

      // 優先選擇邏輯鏡頭 (通常包含 Triple 或 Dual 字樣)，這種鏡頭支援更多縮放範圍 (0.5x - 10x)
      // 若是第一次初始化，才執行自動選擇邏輯
      if (_allBackCameras.isNotEmpty && _controller == null) {
        int bestIndex = 0;
        for (var i = 0; i < _allBackCameras.length; i++) {
          final name = _allBackCameras[i].name.toLowerCase();
          if (name.contains('triple') || name.contains('dual')) {
            bestIndex = i;
            break;
          }
        }
        _currentBackCameraIndex = bestIndex;
      }

      final selectedCamera = _allBackCameras.isNotEmpty
          ? _allBackCameras[_currentBackCameraIndex]
          : cameras.first;

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.veryHigh, // 1080p
        fps: 60,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // 取得縮放範圍並更新狀態
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = min(await _controller!.getMaxZoomLevel(), 10.0);

      // 嘗試設定目標倍率，如果是第一次切換，盡量接近 0.5 或之前的值
      if (_currentZoom < _minZoom) _currentZoom = _minZoom;
      if (_currentZoom > _maxZoom) _currentZoom = _maxZoom;

      await _controller!.setZoomLevel(_currentZoom);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('相機初始化失敗: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('無法存取相機: $e')));
      }
    }
  }

  Future<void> _switchLens() async {
    if (_allBackCameras.length <= 1) return;

    setState(() {
      _isInitialized = false;
    });

    _currentBackCameraIndex =
        (_currentBackCameraIndex + 1) % _allBackCameras.length;
    await _controller?.dispose();
    await _initializeCamera();
    notifyListeners();
  }

  void _listenToRecordingStatus() {
    ref.listen(recordControllerProvider.select((s) => s.status), (
      prev,
      next,
    ) async {
      if (_controller == null || !_controller!.value.isInitialized) return;

      if (next == RecordStatus.recording && prev != RecordStatus.recording) {
        try {
          await _controller!.startVideoRecording();
        } catch (e) {
          if (kDebugMode) print('錄影啟動失敗: $e');
        }
      } else if (next == RecordStatus.uploading &&
          prev == RecordStatus.recording) {
        try {
          final file = await _controller!.stopVideoRecording();
          setState(() {
            _recordedFile = file;
          });
          notifyListeners();
          _processUpload();
        } catch (e) {
          if (kDebugMode) print('錄影停止失敗: $e');
        }
      }
    });

    ref.listen(recordControllerProvider.select((s) => s.sharedRunSessionId), (
      prev,
      next,
    ) {
      if (next != null && _recordedFile != null && !_isUploading) {
        _processUpload();
      }
    });
  }

  Future<void> _processUpload() async {
    if (_recordedFile == null || _isUploading) return;

    final state = ref.read(recordControllerProvider);
    final backend = ref.read(backendProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    // 判斷是否滿足上傳條件
    // 找出所有參與錄影的成員中，最小的相機索引，該成員負責建立 RunSession
    final recordingMembers = state.members
        .where((m) => m.cameraIndex != null)
        .toList();
    recordingMembers.sort((a, b) => a.cameraIndex!.compareTo(b.cameraIndex!));

    final minCameraIndex = recordingMembers.isNotEmpty
        ? recordingMembers.first.cameraIndex
        : 0;
    final isLeader = (state.myCameraIndex == minCameraIndex);

    if (!isLeader && state.sharedRunSessionId == null) {
      if (kDebugMode) print('等待主相機 SessionID...');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      if (kDebugMode) print('開始處理自動上傳: ${state.myCameraIndex}');

      final bytes = await _recordedFile!.readAsBytes();

      String filename = _recordedFile!.name;
      String mimeType =
          lookupMimeType(filename) ??
          _recordedFile!.mimeType ??
          'video/webm'; // Fallback

      // 若檔名沒有副檔名，根據 mimeType 自動補上正確的副檔名
      if (!filename.contains('.')) {
        final ext = extensionFromMime(mimeType);
        if (ext != null) {
          filename = '$filename.$ext';
        } else {
          // 若無法從 mime 判斷，根據常見格式做最後的 fallback
          if (mimeType.contains('mp4')) {
            filename = '$filename.mp4';
          } else {
            filename = '$filename.webm';
          }
        }
      }

      final uploadFile = UploadVideoFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

      final tempVideoId = await backend.uploadVideo(
        state.myCameraIndex ?? 0,
        uploadFile,
      );

      if (isLeader) {
        String? actualRunnerId = state.runnerId;
        if (actualRunnerId == null && state.runnerName != null) {
          actualRunnerId = await backend.addRunner(state.runnerName!);
          if (kDebugMode) print('建立新選手: $actualRunnerId');
        }

        final status = await backend.uploadSeperatelyNew(
          actualRunnerId!,
          DateTime.now(),
          state.expectedCameraCount,
          state.fps,
          state.note,
          state.myCameraIndex!,
          tempVideoId,
        );
        controller.notifyUploadComplete(status.runSessionId);
      } else {
        await backend.uploadSeperatelySelect(
          state.runnerId!,
          state.sharedRunSessionId!,
          state.myCameraIndex!,
          tempVideoId,
        );
      }

      if (kDebugMode) print('自動上傳完成: 相機 ${state.myCameraIndex! + 1}');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _recordedFile = null; // Prevent re-uploading
        });
      }
    } catch (e) {
      if (kDebugMode) print('上傳過程發生錯誤: $e');
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listenToRecordingStatus();

    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const _CameraLoadingShimmer();
    }

    if (_isShowingFullscreen) {
      // 在進入全螢幕模式時，原位留白或顯示 Shimmer，避免兩個 CameraPreview 同時渲染
      return const _CameraLoadingShimmer();
    }

    return _buildCameraPreviewStack(isFullscreen: false);
  }

  void _enterFullscreen() async {
    if (_controller == null) return;
    setState(() {
      _isShowingFullscreen = true;
    });

    // 使用 rootNavigator: true 以確保對話框覆蓋整個 App（包括主頁的 AppBar 與 Sidebar）
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenCameraDialog(cameraViewState: this),
      ),
    );

    if (mounted) {
      setState(() {
        _isShowingFullscreen = false;
      });
    }
  }

  Widget _buildCameraPreviewStack({required bool isFullscreen}) {
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    // 錄影前的驗證邏輯
    final connectedCameraIndexes = state.members
        .map((m) => m.cameraIndex)
        .whereType<int>()
        .toSet();
    final areAllCamerasConnected =
        state.expectedCameraCount > 0 &&
        List.generate(
          state.expectedCameraCount,
          (i) => i,
        ).every((i) => connectedCameraIndexes.contains(i));

    final participatingMembers = state.members.where(
      (m) => m.cameraIndex != null,
    );
    final areAllParticipatingReady = participatingMembers.every(
      (m) => m.isReady,
    );

    // 強制橫式顯示邏輯
    double rawRatio = _controller!.value.aspectRatio;
    double containerAspectRatio = rawRatio;
    int quarterTurns = 0;

    final orientation = MediaQuery.of(context).orientation;

    // 1. 確保外框容器永遠是橫式比例 (> 1)
    if (containerAspectRatio < 1) {
      containerAspectRatio = 1 / containerAspectRatio;
    }

    // 2. 決定是否旋轉內容
    if (orientation == Orientation.portrait && rawRatio < 1) {
      quarterTurns = 3; // 逆時針轉 90 度
    }

    Widget content = Stack(
      children: [
        AspectRatio(
          aspectRatio: containerAspectRatio,
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: CameraPreview(_controller!),
          ),
        ),
        // 縮放控制拉桿
        if (_maxZoom > _minZoom)
          Positioned(
            left: 16,
            bottom: 24,
            top: 24,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SizedBox(
                        width: 200,
                        child: Slider(
                          value: _currentZoom,
                          min: _minZoom,
                          max: _maxZoom,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white30,
                          onChanged: (value) async {
                            setState(() {
                              _currentZoom = value;
                            });
                            notifyListeners();
                            await _controller?.setZoomLevel(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        // 底部更換鏡頭按鈕
        if (_allBackCameras.length > 1)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: GestureDetector(
                  onTap: _switchLens,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "更換鏡頭",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // 右上角縮放按鈕
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: isFullscreen
                ? () => Navigator.of(context, rootNavigator: true).pop()
                : _enterFullscreen,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        // 全螢幕模式下的主控端開始/結束錄影按鈕
        if (isFullscreen && state.role == RecordRole.master)
          Positioned(
            bottom: 24,
            right: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: state.status == RecordStatus.recording
                    ? Colors.black
                    : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                if (state.status == RecordStatus.recording) {
                  controller.stopRecording();
                } else {
                  // 開始錄影前的檢查
                  if (state.runnerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AwesomeSnackbarContent(
                          title: 'Error',
                          message: '請先選擇選手才能開始錄影',
                          contentType: ContentType.failure,
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                      ),
                    );
                    return;
                  }
                  if (!areAllCamerasConnected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AwesomeSnackbarContent(
                          title: 'Error',
                          message:
                              '尚有相機未連線 (目前: ${connectedCameraIndexes.length}/${state.expectedCameraCount})',
                          contentType: ContentType.failure,
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        duration: const Duration(seconds: 2),
                        elevation: 0,
                      ),
                    );
                    return;
                  }

                  if (!areAllParticipatingReady) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AwesomeSnackbarContent(
                          title: 'Warning',
                          message: '部分相機尚未橫放裝置 (未就緒)',
                          contentType: ContentType.warning,
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        duration: const Duration(seconds: 2),
                        elevation: 0,
                      ),
                    );
                    return;
                  }

                  controller.startRecording();
                }
                notifyListeners();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.status == RecordStatus.recording
                        ? Icons.stop
                        : Icons.fiber_manual_record,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.status == RecordStatus.recording ? "停止錄影" : "開始錄影",
                  ),
                ],
              ),
            ),
          ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('自動上傳中...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        if (orientation == Orientation.portrait)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      '請橫放裝置錄製',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (isFullscreen) {
      return content;
    }

    return ClipRRect(borderRadius: BorderRadius.circular(16), child: content);
  }
}

class _FullScreenCameraDialog extends ConsumerStatefulWidget {
  final _RecordCameraViewState cameraViewState;

  const _FullScreenCameraDialog({required this.cameraViewState});

  @override
  ConsumerState<_FullScreenCameraDialog> createState() =>
      _FullScreenCameraDialogState();
}

class _FullScreenCameraDialogState
    extends ConsumerState<_FullScreenCameraDialog> {
  // 定義一個局部方法，用於在收到通知時強制重繪
  void _handleStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 監聽父組件的更新，確保全螢幕下的 local variable (如 _currentZoom) 更新時，此頁面也會重繪
    widget.cameraViewState.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    // 退出時移除監聽，避免記憶體洩漏
    widget.cameraViewState.removeListener(_handleStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 監聽 Riverpod 控制器狀態 (如錄影狀態)，確保按鈕文字會切換
    ref.watch(recordControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        // 直接呼叫父組件的 build 方法來渲染內容
        child: widget.cameraViewState._buildCameraPreviewStack(
          isFullscreen: true,
        ),
      ),
    );
  }
}

class _CameraLoadingShimmer extends StatelessWidget {
  const _CameraLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9, // 使用普遍的橫向比例，與初始化後的預期比例一致
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Shimmer.fromColors(
              baseColor: Theme.of(
                context,
              ).primaryColorDark.withValues(alpha: 0.3),
              highlightColor: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            LoadingIcon(),
          ],
        ),
      ),
    );
  }
}
