import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/feature/record/record_controller.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/upload/widget/anchor_point_dialog.dart';
import 'package:frontend/widget/loading_icon.dart';
import 'package:mime/mime.dart';
import 'package:toastification/toastification.dart';
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

  // Timer? _previewTimer;
  // bool _previewTimerStarted = false;

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
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = min(await _controller!.getMaxZoomLevel(), 10.0);

        // 嘗試設定目標倍率，如果是第一次切換，盡量接近 0.5 或之前的值
        if (_currentZoom < _minZoom) _currentZoom = _minZoom;
        if (_currentZoom > _maxZoom) _currentZoom = _maxZoom;

        if (_maxZoom > _minZoom) {
          await _controller!.setZoomLevel(_currentZoom);
        }
      } catch (e) {
        if (kDebugMode) print('此裝置不支援縮放功能: $e');
        // 發生錯誤時保留預設值 (1.0)，並確保不中斷初始化程序
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _currentZoom = 1.0;
      }

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
        toastification.show(
          context: context,
          title: const Text(
            'Error',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          description: Text('無法存取相機: $e'),
          type: ToastificationType.error,
          style: ToastificationStyle.minimal,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
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

  // void _startPreviewTimer() {
  //   print('start preview timer');
  //   _previewTimer?.cancel();

  //   // 定義傳送預覽圖的邏輯
  //   Future<void> captureAndSend() async {
  //     print('Preview tick...');
  //     if (_controller == null) {
  //       print('Controller is null');
  //       return;
  //     }
  //     if (!_controller!.value.isInitialized) {
  //       print('Controller is not initialized');
  //       return;
  //     }
  //     if (_controller!.value.isTakingPicture) {
  //       print('Controller is currently taking a picture');
  //       return;
  //     }

  //     try {
  //       final xFile = await _controller!.takePicture();
  //       final bytes = await xFile.readAsBytes();
  //       print('Took picture: \${bytes.length} bytes');

  //       final base64String = await compute(_compressAndEncodeImage, bytes);
  //       print('Compressed picture to base64: \${base64String?.length ?? 0} characters');

  //       if (base64String != null && mounted) {
  //         ref
  //             .read(recordControllerProvider.notifier)
  //             .sendCameraPreview("data:image/jpeg;base64,$base64String");
  //         print('Successfully sent preview to backend.');
  //       }
  //     } catch (e, stack) {
  //       print('Failed to capture or send preview: $e\\n$stack');
  //     }
  //   }

  //   // 第一張馬上傳送，然後設定每五秒傳送
  //   captureAndSend();
  //   _previewTimer = Timer.periodic(const Duration(seconds: 5), (_) {
  //     captureAndSend();
  //   });
  // }

  // static String? _compressAndEncodeImage(Uint8List bytes) {
  //   try {
  //     final originalImage = img.decodeImage(bytes);
  //     if (originalImage == null) return null;

  //     // 由於只要確認有沒有錄歪，解析度可以縮小到 320x240，保持長寬比
  //     final resizedImage = img.copyResize(originalImage, width: 320);

  //     // 低品質 JPEG 壓縮，降低網路頻寬使用
  //     final jpgBytes = img.encodeJpg(resizedImage, quality: 30);
  //     return base64Encode(jpgBytes);
  //   } catch (e) {
  //     return null;
  //   }
  // }

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
          state.anchorResult,
        );
        controller.notifyUploadComplete(status.runSessionId);
      } else {
        await backend.uploadSeperatelySelect(
          state.runnerId!,
          state.sharedRunSessionId!,
          state.myCameraIndex!,
          tempVideoId,
          state.anchorResult,
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
    // _previewTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listenToRecordingStatus();

    // final state = ref.watch(recordControllerProvider);
    // if (state.role == RecordRole.slave && !_previewTimerStarted) {
    //   _previewTimerStarted = true;
    //   _startPreviewTimer();
    // } else if (state.role != RecordRole.slave && _previewTimerStarted) {
    //   _previewTimerStarted = false;
    //   _previewTimer?.cancel();
    // }

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

    // Flutter Web: CameraPreview is an HtmlElementView (<video> element).
    // Detaching it from the widget tree breaks the stream connection.
    // Re-initializing the controller before showing fullscreen ensures the
    // fullscreen dialog gets a fresh, properly attached video element.
    setState(() {
      _isShowingFullscreen = true;
      _isInitialized = false; // show shimmer while re-initing
    });
    await _controller?.dispose();
    await _initializeCamera(); // sets _isInitialized = true when done

    if (!mounted) return;

    // 使用 rootNavigator: true 以確保對話框覆蓋整個 App（包括主頁的 AppBar 與 Sidebar）
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenCameraDialog(cameraViewState: this),
      ),
    );

    if (mounted) {
      // Re-initialize again so the normal view also gets a fresh camera element.
      setState(() {
        _isShowingFullscreen = false;
        _isInitialized = false;
      });
      await _controller?.dispose();
      await _initializeCamera();
    }
  }


  Widget _buildCameraPreviewStack({
    required bool isFullscreen,
    bool isAnchorMode = false,
    Widget? anchorOverlay,
  }) {
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              RotatedBox(
                quarterTurns: quarterTurns,
                child: CameraPreview(_controller!),
              ),
              // 如果有錨點層，直接放在這裡，確保座標與影像 1:1 對應
              if (anchorOverlay != null) anchorOverlay,
            ],
          ),
        ),
        // 縮放控制拉桿（錨點模式時隱藏）
        if (!isAnchorMode && _maxZoom > _minZoom)
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
                            try {
                              await _controller?.setZoomLevel(value);
                            } catch (e) {
                              if (kDebugMode) print('無法設定縮放倍率: $e');
                            }
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
        // 底部更換鏡頭按鈕（錨點模式時隱藏）
        if (!isAnchorMode && _allBackCameras.length > 1)
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
        // 右上角縮放按鈕（錨點模式時隱藏）
        if (!isAnchorMode)
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
        // 全螢幕模式下的主控端開始/結束錄影按鈕（錨點模式時隱藏）
        if (!isAnchorMode && isFullscreen && state.role == RecordRole.master)
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
                    toastification.show(
                      context: context,
                      title: const Text(
                        'Error',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      description: const Text('請先選擇選手才能開始錄影'),
                      type: ToastificationType.error,
                      style: ToastificationStyle.minimal,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: const Duration(seconds: 4),
                    );
                    return;
                  }
                  if (!areAllCamerasConnected) {
                    toastification.show(
                      context: context,
                      title: const Text(
                        'Error',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      description: Text(
                        '尚有相機未連線 (目前: ${connectedCameraIndexes.length}/${state.expectedCameraCount})',
                      ),
                      type: ToastificationType.error,
                      style: ToastificationStyle.minimal,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: const Duration(seconds: 4),
                    );
                    return;
                  }

                  if (!areAllParticipatingReady) {
                    toastification.show(
                      context: context,
                      title: const Text(
                        'Warning',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      description: const Text('部分相機尚未橫放裝置 (未就緒)'),
                      type: ToastificationType.warning,
                      style: ToastificationStyle.minimal,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: const Duration(seconds: 4),
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
                  color: Colors.black.withValues(alpha: 0.3),
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
        // 錨點狀態 badge（僅非全螢幕）
        if (!isFullscreen)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: _enterFullscreen, // 引導進入全螢幕設定
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: state.anchorIsSet
                      ? const Color(0xFF00BFA5).withValues(alpha: 0.88)
                      : Colors.deepOrange.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state.anchorIsSet
                        ? const Color(0xFF00BFA5)
                        : Colors.deepOrangeAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.anchorIsSet
                          ? Icons.my_location
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.anchorIsSet
                          ? '錨點已設定'
                          : '請進入全螢幕設定錨點',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NotoSansTC',
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

// ── Anchor overlay constants ────────────────────────────────────
const _kAnchorLabels = ['左上', '右上', '右下', '左下'];
const _kAnchorColors = [
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFE57373),
];
const _kAnchorHitRadius = 12.0;
const _kAnchorMagRadius = 60.0;
const _kAnchorMagZoom = 2.8;

class _FullScreenCameraDialogState
    extends ConsumerState<_FullScreenCameraDialog> {
  // ── Camera state listener ───────────────────────────────────
  void _handleStateChange() {
    if (mounted) setState(() {});
  }

  // ── Anchor mode state ───────────────────────────────────────
  bool _anchorMode = false;
  final List<Offset> _pts = []; // normalised 0–1
  int? _draggingIdx;
  Offset? _magPos;
  Offset? _pendingTapNorm;

  // Cached image size (set in LayoutBuilder inside the anchor overlay)
  double _imgW = 1.0;
  double _imgH = 1.0;

  // Distance text controllers
  final _topCtrl = TextEditingController();
  final _botCtrl = TextEditingController();

  // Distance panel expand/collapse state
  bool _distanceExpanded = false;

  // Snapshot taken when entering anchor mode (for magnifier)
  Uint8List? _snapshotBytes;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    widget.cameraViewState.addListener(_handleStateChange);

    // Pre-load existing anchor if already set
    final existing = ref.read(recordControllerProvider).anchorResult;
    if (existing != null) {
      _pts.addAll(existing.points.map((p) => Offset(p.x, p.y)));
      _topCtrl.text = existing.topDistanceM.toString();
      _botCtrl.text = existing.bottomDistanceM.toString();
    }
  }

  @override
  void dispose() {
    widget.cameraViewState.removeListener(_handleStateChange);
    _topCtrl.dispose();
    _botCtrl.dispose();
    super.dispose();
  }

  // ── Anchor helpers ──────────────────────────────────────────
  bool get _full => _pts.length == 4;
  int get _nextIdx => _pts.length;

  Offset _norm(Offset local) => Offset(
        (local.dx / _imgW).clamp(0.0, 1.0),
        (local.dy / _imgH).clamp(0.0, 1.0),
      );

  int? _nearestIdx(Offset normPos) {
    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < _pts.length; i++) {
      final dx = (normPos.dx - _pts[i].dx) * _imgW;
      final dy = (normPos.dy - _pts[i].dy) * _imgH;
      final d = dx * dx + dy * dy;
      if (d < _kAnchorHitRadius * _kAnchorHitRadius && d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  bool get _canConfirm {
    if (!_full) return false;
    final t = double.tryParse(_topCtrl.text);
    final b = double.tryParse(_botCtrl.text);
    return t != null && t > 0 && b != null && b > 0;
  }

  void _confirmAnchor() {
    final result = AnchorResult(
      points: _pts.map((o) => AnchorPoint(o.dx, o.dy)).toList(),
      topDistanceM: double.parse(_topCtrl.text),
      bottomDistanceM: double.parse(_botCtrl.text),
    );
    ref.read(recordControllerProvider.notifier).setAnchor(result);
    setState(() => _anchorMode = false);
  }

  void _enterAnchorMode() async {
    if (_isCapturing) return;

    // Pre-load current anchor if any
    final existing = ref.read(recordControllerProvider).anchorResult;

    setState(() => _isCapturing = true);

    try {
      // 1. Take a snapshot of the current view for the magnifier
      final xFile = await widget.cameraViewState._controller?.takePicture();
      final bytes = await xFile?.readAsBytes();

      if (mounted) {
        setState(() {
          _pts.clear();
          if (existing != null) {
            _pts.addAll(existing.points.map((p) => Offset(p.x, p.y)));
            _topCtrl.text = existing.topDistanceM.toString();
            _botCtrl.text = existing.bottomDistanceM.toString();
          } else {
            _topCtrl.clear();
            _botCtrl.clear();
          }
          _snapshotBytes = bytes;
          _anchorMode = true;
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('擷取設定錨點預覽圖失敗: $e');
      if (mounted) {
        setState(() {
          _anchorMode = true; // Still enter mode even if snapshot fails
          _isCapturing = false;
        });
      }
    }
  }

  // ── Gesture handlers ────────────────────────────────────────
  void _onTapDown(TapDownDetails d) {
    _pendingTapNorm = _norm(d.localPosition);
  }

  void _onTap() {
    final pos = _pendingTapNorm;
    _pendingTapNorm = null;
    if (pos == null || _full) return;
    if (_nearestIdx(pos) != null) return;
    setState(() => _pts.add(pos));
  }

  void _onPanStart(DragStartDetails d) {
    if (_pts.isEmpty) return;
    final norm = _norm(d.localPosition);
    final idx = _nearestIdx(norm);
    if (idx != null) {
      setState(() {
        _draggingIdx = idx;
        _magPos = _pts[idx];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingIdx == null) return;
    final norm = _norm(d.localPosition);
    setState(() {
      _pts[_draggingIdx!] = norm;
      _magPos = norm;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _draggingIdx = null;
      _magPos = null;
    });
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(recordControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 影像本體
          Center(
            child: RepaintBoundary(
              child: widget.cameraViewState._buildCameraPreviewStack(
                isFullscreen: true,
                isAnchorMode: _anchorMode,
                anchorOverlay: _anchorMode ? _buildAnchorOverlay() : null,
              ),
            ),
          ),
          
          // ── 距離輸入欄位 (在全螢幕的最上方) ──────────────────────
          if (_anchorMode && _full)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: SafeArea(
                child: _buildCollapsibleDistanceRow(),
              ),
            ),

          // 切換按鈕（當不在錨點模式時顯示）
          if (!_anchorMode)
            _isCapturing
                ? const Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : _buildAnchorToggleButton(),
        ],
      ),
    );
  }

  Widget _buildAnchorToggleButton() {
    final isSet = ref.watch(
      recordControllerProvider.select((s) => s.anchorIsSet),
    );
    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
        child: GestureDetector(
          onTap: _enterAnchorMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSet
                  ? const Color(0xFF00BFA5).withValues(alpha: 0.85)
                  : Colors.black54,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSet ? const Color(0xFF00BFA5) : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSet ? Icons.my_location : Icons.location_off_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  isSet ? '錨點已設定' : '設定錨點',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'NotoSansTC',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnchorOverlay() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (_, constraints) {
          _imgW = constraints.maxWidth;
          _imgH = constraints.maxHeight;

          return GestureDetector(
            onTapDown: _onTapDown,
            onTap: _onTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Stack(
                children: [
                  // ── Quadrilateral ──────────────────────────
                  if (_pts.length >= 2)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AnchorQuadPainter(
                          points: _pts,
                          width: _imgW,
                          height: _imgH,
                          draggingIdx: _draggingIdx,
                        ),
                      ),
                    ),

                  // ── Anchor markers ─────────────────────────
                  ..._pts.asMap().entries.map((e) {
                    final i = e.key;
                    final pt = e.value;
                    final isDragging = i == _draggingIdx;
                    return Positioned(
                      left: pt.dx * _imgW - 18,
                      top: pt.dy * _imgH - 18,
                      child: AnimatedScale(
                        scale: isDragging ? 1.35 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: _AnchorMarkerOverlay(
                          label: _kAnchorLabels[i],
                          color: _kAnchorColors[i],
                          index: i + 1,
                          isDragging: isDragging,
                        ),
                      ),
                    );
                  }),

                  // ── Next-point badge（獨立 widget 持有動畫，不影響父層 build）
                  if (!_full && _draggingIdx == null)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _PulsingBadge(
                          color: _kAnchorColors[_nextIdx],
                          label: '點 ${_nextIdx + 1}：${_kAnchorLabels[_nextIdx]}',
                        ),
                      ),
                    ),

                  // ── Magnifier ──────────────────────────────
                  if (_draggingIdx != null && _magPos != null)
                    _buildMagnifier(),

                  // ── Action bar (bottom) ────────────────────
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _buildActionBar(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMagnifier() {
    final norm = _magPos!;
    final cx = norm.dx * _imgW;
    final cy = norm.dy * _imgH;
    const r = _kAnchorMagRadius;
    const zoom = _kAnchorMagZoom;

    double left = cx - r;
    double top = cy - r * 2.4 - 10;
    left = left.clamp(0.0, _imgW - r * 2);
    top = top.clamp(0.0, _imgH - r * 2);

    final tx = r - cx * zoom;
    final ty = r - cy * zoom;
    final dragColor = _kAnchorColors[_draggingIdx!];

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: dragColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: dragColor.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 3,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Background snapshot ────────────────────────
            if (_snapshotBytes != null)
              Positioned(
                left: tx,
                top: ty,
                width: _imgW * zoom,
                height: _imgH * zoom,
                child: Image.memory(
                  _snapshotBytes!,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              )
            else
              Container(color: Colors.black87),

            // ── Crosshair and markers ──────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _LiveMagnifierPainter(
                  normPos: norm,
                  imgW: _imgW,
                  imgH: _imgH,
                  zoom: zoom,
                  tx: tx,
                  ty: ty,
                  points: _pts,
                  draggingIdx: _draggingIdx!,
                  color: dragColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact chip bar when collapsed; full text fields when expanded.
  Widget _buildCollapsibleDistanceRow() {
    final topVal = _topCtrl.text.isEmpty ? '--' : '${_topCtrl.text} m';
    final botVal = _botCtrl.text.isEmpty ? '--' : '${_botCtrl.text} m';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: _distanceExpanded
          // ── Expanded: full input fields ──────────────────────
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with collapse button
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '實際距離',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'NotoSansTC',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _distanceExpanded = false),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Two text fields side by side
                  Row(
                    children: [
                      Expanded(
                        child: _distanceField(
                          controller: _topCtrl,
                          label: '上邊 (m)',
                          color: _kAnchorColors[0],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _distanceField(
                          controller: _botCtrl,
                          label: '下邊 (m)',
                          color: _kAnchorColors[3],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          // ── Collapsed: summary chip ──────────────────────────
          : InkWell(
              onTap: () => setState(() => _distanceExpanded = true),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.straighten,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    // Top edge
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kAnchorColors[0],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      topVal,
                      style: TextStyle(
                        color: _topCtrl.text.isEmpty
                            ? Colors.white38
                            : Colors.white,
                        fontSize: 13,
                        fontFamily: 'NotoSansTC',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bottom edge
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kAnchorColors[3],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      botVal,
                      style: TextStyle(
                        color: _botCtrl.text.isEmpty
                            ? Colors.white38
                            : Colors.white,
                        fontSize: 13,
                        fontFamily: 'NotoSansTC',
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
    );
  }


  Widget _distanceField({
    required TextEditingController controller,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'NotoSansTC',
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '例如 1.22',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            suffixText: 'm',
            suffixStyle: const TextStyle(color: Colors.white54),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        // Cancel
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _anchorMode = false;
            _draggingIdx = null;
            _magPos = null;
          }),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.close, size: 16),
          label: const Text(
            '取消',
            style: TextStyle(fontFamily: 'NotoSansTC'),
          ),
        ),
        const SizedBox(width: 8),
        // Undo
        OutlinedButton.icon(
          onPressed: _pts.isEmpty
              ? null
              : () => setState(() => _pts.removeLast()),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white60,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text(
            '復原',
            style: TextStyle(fontFamily: 'NotoSansTC'),
          ),
        ),
        const SizedBox(width: 8),
        // Reset
        OutlinedButton.icon(
          onPressed: _pts.isEmpty
              ? null
              : () => setState(() => _pts.clear()),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white38,
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(
            '重設',
            style: TextStyle(fontFamily: 'NotoSansTC'),
          ),
        ),
        const Spacer(),
        // Confirm
        AnimatedOpacity(
          opacity: _canConfirm ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            onPressed: _canConfirm ? _confirmAnchor : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              '確認錨點',
              style: TextStyle(
                fontFamily: 'NotoSansTC',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
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

// ── Anchor marker overlay ─────────────────────────────────────

class _AnchorMarkerOverlay extends StatelessWidget {
  final String label;
  final Color color;
  final int index;
  final bool isDragging;

  const _AnchorMarkerOverlay({
    required this.label,
    required this.color,
    required this.index,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isDragging ? 36.0 : 30.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isDragging ? Colors.white : Colors.white70,
              width: isDragging ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDragging ? 0.85 : 0.55),
                blurRadius: isDragging ? 16 : 8,
                spreadRadius: isDragging ? 3 : 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDragging ? 15 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDragging ? 1.0 : 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansTC',
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quad painter for live overlay ────────────────────────────

class _AnchorQuadPainter extends CustomPainter {
  final List<Offset> points;
  final double width;
  final double height;
  final int? draggingIdx;

  const _AnchorQuadPainter({
    required this.points,
    required this.width,
    required this.height,
    this.draggingIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final pts =
        points.map((p) => Offset(p.dx * width, p.dy * height)).toList();

    final paint = Paint()
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pts.length - 1; i++) {
      final isDragEdge = draggingIdx != null &&
          (i == draggingIdx || i + 1 == draggingIdx);
      paint
        ..color =
            _kAnchorColors[i].withValues(alpha: isDragEdge ? 1.0 : 0.8)
        ..strokeWidth = isDragEdge ? 2.8 : 2.2;
      canvas.drawLine(pts[i], pts[i + 1], paint);
    }

    if (pts.length == 4) {
      final isDragEdge =
          draggingIdx != null && (draggingIdx == 3 || draggingIdx == 0);
      paint
        ..color =
            _kAnchorColors[3].withValues(alpha: isDragEdge ? 1.0 : 0.8)
        ..strokeWidth = isDragEdge ? 2.8 : 2.2;
      canvas.drawLine(pts[3], pts[0], paint);

      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2979FF).withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_AnchorQuadPainter old) =>
      old.points != points ||
      old.width != width ||
      old.height != height ||
      old.draggingIdx != draggingIdx;
}

// ── Live magnifier painter ────────────────────────────────────
// Since we cannot clone the CameraPreview texture, we draw the anchor
// positions at zoom scale inside the magnifier circle so the user can
// at least see where the crosshair lands relative to the other points.

class _LiveMagnifierPainter extends CustomPainter {
  final Offset normPos;
  final double imgW;
  final double imgH;
  final double zoom;
  final double tx;
  final double ty;
  final List<Offset> points;
  final int draggingIdx;
  final Color color;

  const _LiveMagnifierPainter({
    required this.normPos,
    required this.imgW,
    required this.imgH,
    required this.zoom,
    required this.tx,
    required this.ty,
    required this.points,
    required this.draggingIdx,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw other anchor point dots at zoomed positions
    for (int i = 0; i < points.length; i++) {
      if (i == draggingIdx) continue;
      final px = points[i].dx * imgW * zoom + tx;
      final py = points[i].dy * imgH * zoom + ty;
      canvas.drawCircle(
        Offset(px, py),
        5,
        Paint()..color = _kAnchorColors[i].withValues(alpha: 0.8),
      );
    }

    // Crosshair lines (gap + line)
    const gap = 6.0;
    const lineLen = 16.0;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx - gap - lineLen, cy), Offset(cx - gap, cy), linePaint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + lineLen, cy), linePaint);
    canvas.drawLine(Offset(cx, cy - gap - lineLen), Offset(cx, cy - gap), linePaint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + lineLen), linePaint);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = color);
    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LiveMagnifierPainter old) => true;
}

// ── Pulsing badge ─────────────────────────────────────────────
// Owns its own AnimationController so parent doesn't rebuild on every tick.

class _PulsingBadge extends StatefulWidget {
  final Color color;
  final String label;

  const _PulsingBadge({required this.color, required this.label});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.scale(
        scale: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansTC',
            ),
          ),
        ),
      ),
    );
  }
}

