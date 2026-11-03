import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/record/record_state.dart';
import 'package:frontend/feature/upload/widget/anchor_point_dialog.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';
import 'package:frontend/feature/upload/upload_controller.dart';
import 'package:frontend/utils/api.dart';
import 'package:frontend/utils/ws_helper/ws_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RecordController extends StateNotifier<RecordState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isIntentionalClose = false;
  bool _isReconnecting = false;
  final Ref _ref;

  RecordController(this._ref) : super(RecordState());

  RecordState get currentState => state;

  String get _wsUrl {
    final baseUrl = API.baseUrl;
    return '${baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}/ws';
  }

  void _disconnect({bool intentional = true}) {
    _isIntentionalClose = intentional;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_subscription != null) {
      try {
        _subscription?.cancel();
      } catch (_) {}
      _subscription = null;
    }

    if (_channel != null) {
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;
    }
  }

  void _connect() {
    _disconnect(intentional: true);
    _isIntentionalClose = false;

    try {
      final uri = Uri.parse(_wsUrl);
      final channel = createWebSocketChannel(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        _listen,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      channel.ready.then((_) {
        _startHeartbeat();
      }).catchError((e) {
        _onError(e);
      });
    } catch (e) {
      _onError(e);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_channel != null && !_isIntentionalClose) {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final msg = RecordMessage(
          type: RecordMessageType.sync,
          data: {'clientSendTime': nowStr},
        );
        try {
          final payload = jsonEncode(msg.toJson());
          _channel?.sink.add(payload);
        } catch (_) {}
      }
    });
  }

  Future<void> _send(RecordMessage msg) async {
    final payload = jsonEncode(msg.toJson());
    try {
      if (_channel == null) {
        _connect();
      }
      await _channel?.ready;
      _channel?.sink.add(payload);
    } catch (e) {
      if (state.roomId != null && !_isIntentionalClose) {
        _scheduleReconnect();
      } else {
        state = state.copyWith(error: '發送訊息失敗: $e');
      }
    }
  }

  void _listen(dynamic message) {
    try {
      final json = jsonDecode(message);
      final msg = RecordMessage.fromJson(json);

      switch (msg.type) {
        case RecordMessageType.sync:
          // 心跳回應，連線健康
          break;
        case RecordMessageType.roomStatus:
          final roomId = msg.data['roomId'];
          final myMemberId = msg.data['myMemberId'] as String?;
          final membersJson = msg.data['members'] as List;
          final members = membersJson.map((e) => RecordMember.fromJson(e)).toList();
          final newStatus =
              (state.status == RecordStatus.idle || state.status == RecordStatus.connecting)
              ? RecordStatus.ready
              : state.status;
          state = state.copyWith(
            status: newStatus,
            roomId: roomId,
            members: members,
            myMemberId: myMemberId ?? state.myMemberId,
            expectedCameraCount: msg.data['expectedCameraCount'] ?? state.expectedCameraCount,
          );
          break;
        case RecordMessageType.startRecording:
          state = state.copyWith(
            status: RecordStatus.recording,
            runnerId: msg.data['runnerId'],
            runnerName: msg.data['runnerName'],
            fps: msg.data['fps'] ?? 60,
            trackWidth: (msg.data['trackWidth'] as num?)?.toDouble() ?? 1.22,
            runningDirection: msg.data['runningDirection'] ?? 'left_to_right',
            note: msg.data['note'] ?? '',
            clearSharedRunSessionId: true,
            isAllUploaded: false,
          );
          break;
        case RecordMessageType.stopRecording:
          state = state.copyWith(status: RecordStatus.uploading, isAllUploaded: false);
          break;
        case RecordMessageType.uploadComplete:
          final isAllUploaded = msg.data['isAllUploaded'] == true;
          state = state.copyWith(
            sharedRunSessionId: msg.data['runSessionId'],
            runnerId: msg.data['runnerId'] ?? state.runnerId,
            isAllUploaded: isAllUploaded,
            status: isAllUploaded ? RecordStatus.ready : state.status,
          );
          break;
        case RecordMessageType.controlRequest:
          state = state.copyWith(pendingControlRequestFrom: msg.data['requesterId']);
          break;
        case RecordMessageType.controlGranted:
          state = state.copyWith(role: RecordRole.master, isWaitingForControlApproval: false);
          break;
        case RecordMessageType.controlRevoked:
          state = state.copyWith(role: RecordRole.slave, isRecordingEnabled: false);
          break;
        case RecordMessageType.controlRejected:
          state = state.copyWith(
            isWaitingForControlApproval: false,
            error: msg.data['message'] ?? '要求控制權被拒絕',
          );
          break;
        case RecordMessageType.error:
          state = state.copyWith(
            status: RecordStatus.idle,
            error: msg.data['message'],
            clearRoomId: true,
            clearMembers: true,
          );
          break;
        case RecordMessageType.notifyNotReady:
          final isParticipatingCamera = (state.role == RecordRole.slave && state.myCameraIndex != null) ||
              (state.role == RecordRole.master && state.isRecordingEnabled && state.myCameraIndex != null);
          final isReady = state.isPhysicallyReady && state.anchorIsSet;
          if (isParticipatingCamera && !isReady) {
            state = state.copyWith(notReadyAlertTick: state.notReadyAlertTick + 1);
          }
          break;
        case RecordMessageType.kicked:
          _disconnect(intentional: true);
          state = RecordState(
            error: msg.data['message'] ?? 'kickedByHost',
            activeCameraName: state.activeCameraName,
            activeCameraSpecs: state.activeCameraSpecs,
            isPhysicallyReady: state.isPhysicallyReady,
          );
          break;
        default:
          break;
      }
    } catch (_) {}
  }

  void _onError(dynamic error) {
    if (_isIntentionalClose) return;

    if (state.roomId != null && state.status != RecordStatus.idle) {
      _scheduleReconnect();
    } else {
      state = state.copyWith(error: '連線錯誤: $error');
    }
  }

  void _onDone() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_isIntentionalClose) return;

    if (state.roomId != null && state.status != RecordStatus.idle) {
      _scheduleReconnect();
    } else {
      if (state.status == RecordStatus.connecting) {
        state = state.copyWith(
          status: RecordStatus.idle,
          error: '連線已斷開',
          clearRoomId: true,
          clearMembers: true,
        );
      } else if (state.status != RecordStatus.idle) {
        state = state.copyWith(error: '連線中斷');
      }
    }
  }

  void _scheduleReconnect() {
    if (_isIntentionalClose || _isReconnecting) return;
    _isReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 1500), () async {
      _isReconnecting = false;
      if (_isIntentionalClose || state.roomId == null || state.status == RecordStatus.idle) return;
      _connect();
      try {
        await _channel?.ready;
        if (state.role == RecordRole.master) {
          final msg = RecordMessage(
            type: RecordMessageType.joinRoom,
            data: {
              'roomId': state.roomId,
              'cameraIndex': state.myCameraIndex,
              'isMaster': true,
            },
          );
          await _send(msg);
        } else {
          final msg = RecordMessage(
            type: RecordMessageType.joinRoom,
            data: {
              'roomId': state.roomId,
              'cameraIndex': state.myCameraIndex,
              'isMaster': false,
            },
          );
          await _send(msg);
          if (state.isPhysicallyReady && state.anchorIsSet) {
            updateReadyStatus(true);
          }
        }
      } catch (_) {
        if (state.roomId != null && !_isIntentionalClose) {
          _scheduleReconnect();
        }
      }
    });
  }

  void createRoom(int expectedCameraCount) {
    _disconnect(intentional: true);
    state = RecordState(
      status: RecordStatus.connecting,
      role: RecordRole.master,
      expectedCameraCount: expectedCameraCount,
      myCameraIndex: state.isRecordingEnabled ? state.myCameraIndex : null,
      isRecordingEnabled: state.isRecordingEnabled,
      isPhysicallyReady: state.isPhysicallyReady,
      activeCameraName: state.activeCameraName,
      activeCameraSpecs: state.activeCameraSpecs,
    );
    _connect();
    final msg = RecordMessage(
      type: RecordMessageType.createRoom,
      data: {'expectedCameraCount': expectedCameraCount},
    );
    _send(msg);
  }

  void toggleMasterRecording(bool enabled, [int? index]) {
    state = state.copyWith(
      isRecordingEnabled: enabled,
      myCameraIndex: enabled ? index : null,
      activeCameraName: enabled ? state.activeCameraName : null,
      activeCameraSpecs: enabled ? state.activeCameraSpecs : null,
    );

    if (state.status == RecordStatus.ready) {
      // 1. 回報加入/離開為相機身分
      final msg = RecordMessage(
        type: RecordMessageType.joinRoom,
        data: {
          'roomId': state.roomId,
          'cameraIndex': enabled ? index : null,
          'isMaster': true,
          'cameraName': enabled ? state.activeCameraName : null,
          'cameraSpecs': enabled ? state.activeCameraSpecs : null,
        },
      );
      _send(msg);

      // 2. 如果是正在加入且目前設備已橫放，則立即主動補送 Ready 狀態
      if (enabled && state.isPhysicallyReady) {
        updateReadyStatus(true);
      }
    }
  }

  /// Sets the anchor calibration result and re-evaluates ready status.
  void setAnchor(AnchorResult? anchor) {
    state = state.copyWith(anchorResult: anchor, clearAnchor: anchor == null);
    // Re-send ready status if we now have (or lost) the anchor
    if (state.myCameraIndex != null) {
      updateReadyStatus(state.isPhysicallyReady && state.anchorIsSet);
    }
  }

  /// 更新本機端的物理轉向狀態，並視情況向後端同步
  void updatePhysicallyReady(bool isReady) {
    if (state.isPhysicallyReady == isReady) return;

    state = state.copyWith(isPhysicallyReady: isReady);

    // 只有在已分配相機編號（正式參與錄影）時才需要發送給後端
    // 同時必須錨點也設定完畢，才算真正 Ready
    if (state.myCameraIndex != null) {
      updateReadyStatus(isReady && state.anchorIsSet);
    }
  }

  void joinRoom(String roomId, int cameraIndex) {
    final cleanRoomId = roomId.trim().toUpperCase();
    final alreadyInThisRoom = state.roomId == cleanRoomId && _channel != null;

    if (!alreadyInThisRoom) {
      _disconnect(intentional: true);
      state = RecordState(
        status: RecordStatus.connecting,
        role: RecordRole.slave,
        roomId: cleanRoomId,
        myCameraIndex: cameraIndex,
        isPhysicallyReady: state.isPhysicallyReady,
        activeCameraName: state.activeCameraName,
        activeCameraSpecs: state.activeCameraSpecs,
      );
      _connect();
    } else {
      state = state.copyWith(
        role: RecordRole.slave,
        roomId: cleanRoomId,
        myCameraIndex: cameraIndex,
        clearSharedRunSessionId: true,
        clearError: true,
      );
    }

    final msg = RecordMessage(
      type: RecordMessageType.joinRoom,
      data: {
        'roomId': cleanRoomId,
        'cameraIndex': cameraIndex,
        'isMaster': false,
        'cameraName': state.activeCameraName,
        'cameraSpecs': state.activeCameraSpecs,
      },
    );
    _send(msg);
  }

  void setRunnerSource(RunnerSource source) {
    state = state.copyWith(runnerSource: source);
  }

  void setRunner(String? id, [String? name]) {
    state = state.copyWith(runnerId: id, runnerName: name);
  }

  Future<String> addRunner(String name) async {
    final runnerInfo = await _ref.read(uploadRunnerListProvider.notifier).addRunner(name);
    state = state.copyWith(
      runnerId: runnerInfo.id,
      runnerName: name,
      runnerSource: RunnerSource.select,
    );
    return runnerInfo.id;
  }

  void setFps(int fps) {
    state = state.copyWith(fps: fps);
  }

  void setTrackWidth(double trackWidth) {
    state = state.copyWith(trackWidth: trackWidth);
  }

  void setRunningDirection(String direction) {
    state = state.copyWith(runningDirection: direction);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void updateCameraInfo({String? name, String? specs}) {
    state = state.copyWith(
      activeCameraName: name,
      activeCameraSpecs: specs,
    );
    if (state.roomId != null && state.status != RecordStatus.idle) {
      final isParticipating = (state.role == RecordRole.slave && state.myCameraIndex != null) ||
          (state.role == RecordRole.master && state.isRecordingEnabled && state.myCameraIndex != null);
      final msg = RecordMessage(
        type: RecordMessageType.updateCameraInfo,
        data: {
          'cameraName': isParticipating ? name : null,
          'cameraSpecs': isParticipating ? specs : null,
        },
      );
      _send(msg);
    }
  }

  void startRecording() {
    if (state.role != RecordRole.master) {
      return;
    }
    final msg = RecordMessage(
      type: RecordMessageType.startRecording,
      data: {
        'runnerId': state.runnerId,
        'runnerName': state.runnerName,
        'fps': state.fps,
        'trackWidth': state.trackWidth,
        'runningDirection': state.runningDirection,
        'note': state.note,
      },
    );
    _send(msg);
  }

  void notifyNotReady() {
    final msg = RecordMessage(
      type: RecordMessageType.notifyNotReady,
      data: {},
    );
    _send(msg);
  }

  void kickMember(String targetMemberId) {
    if (state.role != RecordRole.master) return;
    final msg = RecordMessage(
      type: RecordMessageType.kickMember,
      data: {'targetMemberId': targetMemberId},
    );
    _send(msg);
  }

  void stopRecording() {
    if (state.role != RecordRole.master) return;
    final msg = RecordMessage(type: RecordMessageType.stopRecording, data: {});
    _send(msg);
  }

  void notifyUploadComplete(String runSessionId, {String? runnerId, bool isAllUploaded = false}) {
    final msg = RecordMessage(
      type: RecordMessageType.uploadComplete,
      data: {
        'runSessionId': runSessionId,
        if (runnerId != null) 'runnerId': runnerId,
        'isAllUploaded': isAllUploaded,
      },
    );
    _send(msg);
  }

  void updateReadyStatus(bool isReady) {
    if (state.status != RecordStatus.ready) return;
    final msg = RecordMessage(type: RecordMessageType.updateReady, data: {'isReady': isReady});
    _send(msg);
  }

  void sendCameraPreview(String base64Image) {
    if (state.role != RecordRole.slave) return;
    final msg = RecordMessage(type: RecordMessageType.cameraPreview, data: {'image': base64Image});
    _send(msg);
  }

  void requestControl() {
    state = state.copyWith(isWaitingForControlApproval: true);
    final msg = RecordMessage(type: RecordMessageType.requestControl, data: {});
    _send(msg);
  }

  void respondControlRequest(String requesterId, bool agree) {
    state = state.copyWith(clearPendingControlRequest: true);
    final msg = RecordMessage(
      type: RecordMessageType.respondControlRequest,
      data: {'requesterId': requesterId, 'agree': agree},
    );
    _send(msg);
  }

  void leaveRoom({bool resetState = true}) {
    try {
      final msg = RecordMessage(type: RecordMessageType.leaveRoom, data: {});
      _channel?.sink.add(jsonEncode(msg.toJson()));
    } catch (_) {}
    _disconnect(intentional: true);
    if (resetState) {
      scheduleMicrotask(() {
        if (mounted) {
          state = RecordState(
            activeCameraName: state.activeCameraName,
            activeCameraSpecs: state.activeCameraSpecs,
            isPhysicallyReady: state.isPhysicallyReady,
          );
        }
      });
    }
  }

  void resetRoomState() {
    _disconnect(intentional: true);
    state = RecordState(
      activeCameraName: state.activeCameraName,
      activeCameraSpecs: state.activeCameraSpecs,
      isPhysicallyReady: state.isPhysicallyReady,
    );
  }

  @override
  void dispose() {
    _disconnect(intentional: true);
    super.dispose();
  }
}

final recordControllerProvider = StateNotifierProvider<RecordController, RecordState>((
  ref,
) {
  return RecordController(ref);
});

final recordTourDemoInRoomProvider = StateProvider<bool>((ref) => false);
final recordTourDemoRoleProvider = StateProvider<RecordRole>((ref) => RecordRole.master);

final recordTourAnchorFullscreenOpenProvider = StateProvider<bool>((ref) => false);

enum RecordTourAnchorStage {
  normalFullscreen, // 全螢幕相機預覽（尚未進入錨點設定）
  anchorMode, // 6 點跑道錨點校正畫布模式
  distanceDialog, // 輸入跑道實際物理長度對話框
  calibratedFullscreen, // 校正完成後的全螢幕預覽（無錨點殘留，左上角綠燈就緒）
}

final recordTourAnchorStageProvider = StateProvider<RecordTourAnchorStage>(
  (ref) => RecordTourAnchorStage.normalFullscreen,
);
