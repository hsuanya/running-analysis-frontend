import 'package:frontend/feature/record/record_enums.dart';
import 'package:frontend/feature/upload/widget/anchor_point_dialog.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';

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
  });

  bool get anchorIsSet => anchorResult != null;

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
    );
  }
}
