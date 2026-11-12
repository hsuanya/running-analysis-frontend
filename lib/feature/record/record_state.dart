import 'dart:typed_data';
import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/upload/widget/anchor_point_dialog.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';

class RecordingMetadataSnapshot {
  final String? runSessionId;
  final String? runnerId;
  final String? runnerName;
  final DateTime recordedAt;
  final int cameraIndex;
  final int expectedCameraCount;
  final int fps;
  final double trackWidth;
  final String runningDirection;
  final String note;
  final AnchorResult? anchorResult;

  const RecordingMetadataSnapshot({
    this.runSessionId,
    this.runnerId,
    this.runnerName,
    required this.recordedAt,
    required this.cameraIndex,
    required this.expectedCameraCount,
    required this.fps,
    required this.trackWidth,
    required this.runningDirection,
    required this.note,
    this.anchorResult,
  });

  Map<String, dynamic> toJson() => {
    'runSessionId': runSessionId,
    'runnerId': runnerId,
    'runnerName': runnerName,
    'recordedAt': recordedAt.toIso8601String(),
    'cameraIndex': cameraIndex,
    'expectedCameraCount': expectedCameraCount,
    'fps': fps,
    'trackWidth': trackWidth,
    'runningDirection': runningDirection,
    'note': note,
    'anchorResult': anchorResult?.toJson(),
  };

  factory RecordingMetadataSnapshot.fromJson(Map<String, dynamic> json) {
    AnchorResult? anchor;
    final rawAnchor = json['anchorResult'];
    if (rawAnchor is Map) {
      final ptsRaw = rawAnchor['points'];
      final pts = ptsRaw is List
          ? ptsRaw
                .whereType<Map>()
                .map(
                  (p) => AnchorPoint(
                    (p['x'] as num?)?.toDouble() ?? 0.0,
                    (p['y'] as num?)?.toDouble() ?? 0.0,
                  ),
                )
                .toList()
          : <AnchorPoint>[];
      if (pts.isNotEmpty) {
        anchor = AnchorResult(
          points: pts,
          leftToMidDistanceM: (rawAnchor['leftToMidDistanceM'] as num?)?.toDouble() ?? 5.0,
          midToRightDistanceM: (rawAnchor['midToRightDistanceM'] as num?)?.toDouble() ?? 5.0,
        );
      }
    }
    DateTime dt = DateTime.now();
    if (json['recordedAt'] is String) {
      try {
        dt = DateTime.parse(json['recordedAt'] as String);
      } catch (_) {}
    }
    return RecordingMetadataSnapshot(
      runSessionId: json['runSessionId'] as String?,
      runnerId: json['runnerId'] as String?,
      runnerName: json['runnerName'] as String?,
      recordedAt: dt,
      cameraIndex: (json['cameraIndex'] as num?)?.toInt() ?? 0,
      expectedCameraCount: (json['expectedCameraCount'] as num?)?.toInt() ?? 1,
      fps: (json['fps'] as num?)?.toInt() ?? 60,
      trackWidth: (json['trackWidth'] as num?)?.toDouble() ?? 1.22,
      runningDirection: (json['runningDirection'] as String?) ?? 'left_to_right',
      note: (json['note'] as String?) ?? '',
      anchorResult: anchor,
    );
  }
}

class PendingVideoUploadItem {
  final String id;
  final RecordingMetadataSnapshot snapshot;
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final PendingUploadStatus status;
  final String? errorMessage;

  const PendingVideoUploadItem({
    required this.id,
    required this.snapshot,
    required this.bytes,
    required this.filename,
    required this.mimeType,
    this.status = PendingUploadStatus.queued,
    this.errorMessage,
  });

  double get sizeInMb => bytes.lengthInBytes / (1024 * 1024);

  PendingVideoUploadItem copyWith({
    PendingUploadStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PendingVideoUploadItem(
      id: id,
      snapshot: snapshot,
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MyRoomInfo {
  final String roomId;
  final int expectedCameraCount;
  final int connectedDeviceCount;
  final List<int> occupiedCameraIndexes;
  final String recordingStatus;

  const MyRoomInfo({
    required this.roomId,
    required this.expectedCameraCount,
    required this.connectedDeviceCount,
    required this.occupiedCameraIndexes,
    this.recordingStatus = 'idle',
  });

  factory MyRoomInfo.fromJson(Map<String, dynamic> json) {
    final occupiedRaw = json['occupiedCameraIndexes'];
    final occupied = occupiedRaw is List
        ? occupiedRaw.map((e) => (e as num).toInt()).toList()
        : <int>[];
    return MyRoomInfo(
      roomId: (json['roomId'] ?? '').toString(),
      expectedCameraCount: (json['expectedCameraCount'] as num?)?.toInt() ?? 1,
      connectedDeviceCount: (json['connectedDeviceCount'] as num?)?.toInt() ?? 1,
      occupiedCameraIndexes: occupied,
      recordingStatus: (json['recordingStatus'] ?? 'idle').toString(),
    );
  }
}

class RecordState {
  final RecordRole role;
  final RecordStatus status;
  final String? roomId;
  final List<RecordMember> members;
  final String? error;
  final int? myDeviceInfoIndex; // For Slave to know which camera it is
  final int? myCameraIndex; // Assigned camera index (0-4)
  final String? sharedRunSessionId; // Synced after first upload
  final String? myMemberId; // Unique member ID of this connection
  final int expectedCameraCount;
  final bool isRecordingEnabled; // For Master
  final bool isPhysicallyReady; // Track local physical orientation (landscape)

  // Upload Parameters
  final RunnerSource runnerSource;
  final String? runnerId;
  final String? runnerName; // For "Add New Runner" case
  final int fps;
  final double trackWidth;
  final String runningDirection;
  final String note;

  // Calibration
  final AnchorResult? anchorResult;

  // Upload Progress
  final bool isAllUploaded;

  // Room Control Request
  final String? pendingControlRequestFrom;
  final bool isWaitingForControlApproval;

  // Not Ready Alert Tick
  final int notReadyAlertTick;

  // Active Camera Specs & Name
  final String? activeCameraSpecs;
  final String? activeCameraName;

  // Active Rooms Owned by Current User
  final List<MyRoomInfo> myRooms;
  final bool isLoadingMyRooms;

  // Slow Network Mode & Background Upload Queue
  final bool slowNetworkMode;
  final bool pauseAutoUpload;
  final String? currentRecordingSessionId;
  final DateTime? currentRecordedAt;
  final RecordingMetadataSnapshot? lastCompletedRecordingMeta;
  final int stopRecordingQueueTick;
  final List<PendingVideoUploadItem> uploadQueue;
  final bool isProcessingQueue;

  RecordState({
    this.role = RecordRole.none,
    this.status = RecordStatus.idle,
    this.roomId,
    this.members = const [],
    this.error,
    this.myDeviceInfoIndex,
    this.myCameraIndex,
    this.sharedRunSessionId,
    this.myMemberId,
    this.expectedCameraCount = 0,
    this.isRecordingEnabled = false,
    this.isPhysicallyReady = false,
    this.runnerSource = RunnerSource.select,
    this.runnerId,
    this.runnerName,
    this.fps = 60,
    this.trackWidth = 1.22,
    this.runningDirection = 'left_to_right',
    this.note = '',
    this.anchorResult,
    this.isAllUploaded = false,
    this.pendingControlRequestFrom,
    this.isWaitingForControlApproval = false,
    this.notReadyAlertTick = 0,
    this.activeCameraSpecs,
    this.activeCameraName,
    this.myRooms = const [],
    this.isLoadingMyRooms = false,
    this.slowNetworkMode = false,
    this.pauseAutoUpload = false,
    this.currentRecordingSessionId,
    this.currentRecordedAt,
    this.lastCompletedRecordingMeta,
    this.stopRecordingQueueTick = 0,
    this.uploadQueue = const [],
    this.isProcessingQueue = false,
  });

  bool get anchorIsSet => anchorResult != null;

  int get pendingQueueCount => uploadQueue
      .where((i) =>
          i.status == PendingUploadStatus.queued ||
          i.status == PendingUploadStatus.uploading ||
          i.status == PendingUploadStatus.failed)
      .length;

  RecordState copyWith({
    RecordRole? role,
    RecordStatus? status,
    String? roomId,
    List<RecordMember>? members,
    String? error,
    int? myDeviceInfoIndex,
    int? myCameraIndex,
    String? sharedRunSessionId,
    String? myMemberId,
    int? expectedCameraCount,
    bool? isRecordingEnabled,
    bool? isPhysicallyReady,
    RunnerSource? runnerSource,
    String? runnerId,
    String? runnerName,
    int? fps,
    double? trackWidth,
    String? runningDirection,
    String? note,
    AnchorResult? anchorResult,
    bool? isAllUploaded,
    bool clearAnchor = false,
    bool clearSharedRunSessionId = false,
    String? pendingControlRequestFrom,
    bool? isWaitingForControlApproval,
    bool clearPendingControlRequest = false,
    bool clearRoomId = false,
    bool clearMembers = false,
    bool clearError = false,
    bool clearRunner = false,
    bool clearMyCameraIndex = false,
    int? notReadyAlertTick,
    String? activeCameraSpecs,
    String? activeCameraName,
    List<MyRoomInfo>? myRooms,
    bool? isLoadingMyRooms,
    bool? slowNetworkMode,
    bool? pauseAutoUpload,
    String? currentRecordingSessionId,
    DateTime? currentRecordedAt,
    RecordingMetadataSnapshot? lastCompletedRecordingMeta,
    int? stopRecordingQueueTick,
    List<PendingVideoUploadItem>? uploadQueue,
    bool? isProcessingQueue,
  }) {
    return RecordState(
      role: role ?? this.role,
      status: status ?? this.status,
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      members: clearMembers ? const [] : (members ?? this.members),
      error: clearError ? null : (error ?? this.error),
      myDeviceInfoIndex: myDeviceInfoIndex ?? this.myDeviceInfoIndex,
      myCameraIndex: clearMyCameraIndex ? null : (myCameraIndex ?? this.myCameraIndex),
      sharedRunSessionId: clearSharedRunSessionId
          ? null
          : (sharedRunSessionId ?? this.sharedRunSessionId),
      myMemberId: myMemberId ?? this.myMemberId,
      expectedCameraCount: expectedCameraCount ?? this.expectedCameraCount,
      isRecordingEnabled: isRecordingEnabled ?? this.isRecordingEnabled,
      isPhysicallyReady: isPhysicallyReady ?? this.isPhysicallyReady,
      runnerSource: runnerSource ?? this.runnerSource,
      runnerId: clearRunner ? null : (runnerId ?? this.runnerId),
      runnerName: clearRunner ? null : (runnerName ?? this.runnerName),
      fps: fps ?? this.fps,
      trackWidth: trackWidth ?? this.trackWidth,
      runningDirection: runningDirection ?? this.runningDirection,
      note: note ?? this.note,
      anchorResult: clearAnchor ? null : (anchorResult ?? this.anchorResult),
      isAllUploaded: isAllUploaded ?? this.isAllUploaded,
      pendingControlRequestFrom: clearPendingControlRequest
          ? null
          : (pendingControlRequestFrom ?? this.pendingControlRequestFrom),
      isWaitingForControlApproval: isWaitingForControlApproval ?? this.isWaitingForControlApproval,
      notReadyAlertTick: notReadyAlertTick ?? this.notReadyAlertTick,
      activeCameraSpecs: activeCameraSpecs ?? this.activeCameraSpecs,
      activeCameraName: activeCameraName ?? this.activeCameraName,
      myRooms: myRooms ?? this.myRooms,
      isLoadingMyRooms: isLoadingMyRooms ?? this.isLoadingMyRooms,
      slowNetworkMode: slowNetworkMode ?? this.slowNetworkMode,
      pauseAutoUpload: pauseAutoUpload ?? this.pauseAutoUpload,
      currentRecordingSessionId: currentRecordingSessionId ?? this.currentRecordingSessionId,
      currentRecordedAt: currentRecordedAt ?? this.currentRecordedAt,
      lastCompletedRecordingMeta: lastCompletedRecordingMeta ?? this.lastCompletedRecordingMeta,
      stopRecordingQueueTick: stopRecordingQueueTick ?? this.stopRecordingQueueTick,
      uploadQueue: uploadQueue ?? this.uploadQueue,
      isProcessingQueue: isProcessingQueue ?? this.isProcessingQueue,
    );
  }
}
