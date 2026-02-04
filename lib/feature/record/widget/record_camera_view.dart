import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/feature/record/record_controller.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:mime/mime.dart';

class RecordCameraView extends ConsumerStatefulWidget {
  const RecordCameraView({super.key});

  @override
  ConsumerState<RecordCameraView> createState() => _RecordCameraViewState();
}

class _RecordCameraViewState extends ConsumerState<RecordCameraView> {
  CameraController? _controller;
  bool _isInitialized = false;
  XFile? _recordedFile;
  bool _isUploading = false;
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

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh, // 1080p
        fps: 60,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // 取得縮放範圍並嘗試設定為 0.5
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();

      // 嘗試設定目標倍率為 0.5
      _currentZoom = 0.5;
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
      return const Center(child: CircularProgressIndicator());
    }

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
    // 只有在裝置直向 (Portrait) 且原始畫面是直的 (rawRatio < 1) 時，才需要強制轉 90 度
    if (orientation == Orientation.portrait && rawRatio < 1) {
      quarterTurns = 3; // 逆時針轉 90 度
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
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
                  bottom: 16,
                  top: 16,
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
                            await _controller?.setZoomLevel(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              // 倍率數值顯示
              Positioned(
                left: 24,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
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
  }
}
