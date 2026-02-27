import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/backend/backend_interface.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/record/record_state.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';
import 'package:frontend/utils/api.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RecordController extends StateNotifier<RecordState> {
  WebSocketChannel? _channel;
  final BackendInterface _backend;

  RecordController(this._backend) : super(RecordState());

  String get _wsUrl {
    final baseUrl = API.baseUrl;
    final url =
        '${baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}/ws';

    return url;
  }

  void _connect() {
    _channel?.sink.close();
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    _channel!.ready.catchError((e) {
      _onError(e);
    });
    _channel!.stream.listen(_listen, onError: _onError, onDone: _onDone);
  }

  void _listen(dynamic message) {
    final json = jsonDecode(message);
    final msg = RecordMessage.fromJson(json);

    switch (msg.type) {
      case RecordMessageType.roomStatus:
        final roomId = msg.data['roomId'];
        final membersJson = msg.data['members'] as List;
        final members = membersJson
            .map((e) => RecordMember.fromJson(e))
            .toList();
        state = state.copyWith(
          status: RecordStatus.ready,
          roomId: roomId,
          members: members,
          expectedCameraCount:
              msg.data['expectedCameraCount'] ?? state.expectedCameraCount,
        );
        break;
      case RecordMessageType.startRecording:
        state = state.copyWith(
          status: RecordStatus.recording,
          runnerId: msg.data['runnerId'],
          runnerName: msg.data['runnerName'],
          fps: msg.data['fps'] ?? 60,
          note: msg.data['note'] ?? '',
        );
        break;
      case RecordMessageType.stopRecording:
        state = state.copyWith(status: RecordStatus.uploading);
        break;
      case RecordMessageType.uploadComplete:
        state = state.copyWith(sharedRunSessionId: msg.data['runSessionId']);
        break;
      case RecordMessageType.error:
        state = state.copyWith(
          status: RecordStatus.idle,
          error: msg.data['message'],
        );
        break;
      default:
        break;
    }
  }

  void _onError(error) {
    state = state.copyWith(status: RecordStatus.idle, error: '連線錯誤: $error');
  }

  void _onDone() {
    if (state.status != RecordStatus.idle) {
      state = state.copyWith(status: RecordStatus.idle, error: '連線已斷開');
    }
  }

  void createRoom(int expectedCameraCount) {
    state = state.copyWith(
      status: RecordStatus.connecting,
      role: RecordRole.master,
      expectedCameraCount: expectedCameraCount,
      myCameraIndex: state.isRecordingEnabled ? state.myCameraIndex : null,
    );
    _connect();
    final msg = RecordMessage(
      type: RecordMessageType.createRoom,
      data: {'expectedCameraCount': expectedCameraCount},
    );
    _channel!.sink.add(jsonEncode(msg.toJson()));
  }

  void toggleMasterRecording(bool enabled, [int? index]) {
    state = state.copyWith(
      isRecordingEnabled: enabled,
      myCameraIndex: enabled ? index : null,
    );

    if (state.status == RecordStatus.ready) {
      // 1. 回報加入/離開為相機身分
      final msg = RecordMessage(
        type: RecordMessageType.joinRoom,
        data: {
          'roomId': state.roomId,
          'cameraIndex': enabled ? index : null,
          'isMaster': true,
        },
      );
      _channel?.sink.add(jsonEncode(msg.toJson()));

      // 2. 如果是正在加入且目前設備已橫放，則立即主動補送 Ready 狀態
      if (enabled && state.isPhysicallyReady) {
        updateReadyStatus(true);
      }
    }
  }

  /// 更新本機端的物理轉向狀態，並視情況向後端同步
  void updatePhysicallyReady(bool isReady) {
    if (state.isPhysicallyReady == isReady) return;

    state = state.copyWith(isPhysicallyReady: isReady);

    // 只有在已分配相機編號（正式參與錄影）時才需要發送給後端
    if (state.myCameraIndex != null) {
      updateReadyStatus(isReady);
    }
  }

  void joinRoom(String roomId, int cameraIndex) {
    state = state.copyWith(
      status: RecordStatus.connecting,
      role: RecordRole.slave,
      roomId: roomId,
      myCameraIndex: cameraIndex,
    );
    _connect();
    final msg = RecordMessage(
      type: RecordMessageType.joinRoom,
      data: {'roomId': roomId, 'cameraIndex': cameraIndex},
    );
    _channel!.sink.add(jsonEncode(msg.toJson()));
  }

  void setRunnerSource(RunnerSource source) {
    state = state.copyWith(runnerSource: source);
  }

  void setRunner(String? id, [String? name]) {
    state = state.copyWith(runnerId: id, runnerName: name);
  }

  Future<String> addRunner(String name) async {
    final runnerId = await _backend.addRunner(name);
    state = state.copyWith(
      runnerId: runnerId,
      runnerName: name,
      runnerSource: RunnerSource.select,
    );
    return runnerId;
  }

  void setFps(int fps) {
    state = state.copyWith(fps: fps);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void startRecording() {
    if (state.role != RecordRole.master) return;
    final msg = RecordMessage(
      type: RecordMessageType.startRecording,
      data: {
        'runnerId': state.runnerId,
        'runnerName': state.runnerName,
        'fps': state.fps,
        'note': state.note,
      },
    );
    _channel?.sink.add(jsonEncode(msg.toJson()));
  }

  void stopRecording() {
    if (state.role != RecordRole.master) return;
    final msg = RecordMessage(type: RecordMessageType.stopRecording, data: {});
    _channel?.sink.add(jsonEncode(msg.toJson()));
  }

  void notifyUploadComplete(String runSessionId) {
    final msg = RecordMessage(
      type: RecordMessageType.uploadComplete,
      data: {'runSessionId': runSessionId},
    );
    _channel?.sink.add(jsonEncode(msg.toJson()));
  }

  void updateReadyStatus(bool isReady) {
    if (state.status != RecordStatus.ready) return;
    final msg = RecordMessage(
      type: RecordMessageType.updateReady,
      data: {'isReady': isReady},
    );
    _channel?.sink.add(jsonEncode(msg.toJson()));
  }

  void leaveRoom() {
    _channel?.sink.close();
    state = RecordState();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

final recordControllerProvider =
    StateNotifierProvider.autoDispose<RecordController, RecordState>((ref) {
      final backend = ref.watch(backendProvider);
      return RecordController(backend);
    });
