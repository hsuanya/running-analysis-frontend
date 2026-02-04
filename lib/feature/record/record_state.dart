import 'package:frontend/feature/record/record_enums.dart';
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
  final int expectedCameraCount;
  final bool isRecordingEnabled; // For Master

  // Upload Parameters
  final RunnerSource runnerSource;
  final String? runnerId;
  final String? runnerName; // For "Add New Runner" case
  final int fps;
  final String note;

  RecordState({
    this.role = RecordRole.none,
    this.status = RecordStatus.idle,
    this.roomId,
    this.members = const [],
    this.error,
    this.myDeviceInfoIndex,
    this.myCameraIndex,
    this.sharedRunSessionId,
    this.expectedCameraCount = 0,
    this.isRecordingEnabled = false,
    this.runnerSource = RunnerSource.select,
    this.runnerId,
    this.runnerName,
    this.fps = 60,
    this.note = '',
  });

  RecordState copyWith({
    RecordRole? role,
    RecordStatus? status,
    String? roomId,
    List<RecordMember>? members,
    String? error,
    int? myDeviceInfoIndex,
    int? myCameraIndex,
    String? sharedRunSessionId,
    int? expectedCameraCount,
    bool? isRecordingEnabled,
    RunnerSource? runnerSource,
    String? runnerId,
    String? runnerName,
    int? fps,
    String? note,
  }) {
    return RecordState(
      role: role ?? this.role,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      members: members ?? this.members,
      error: error,
      myDeviceInfoIndex: myDeviceInfoIndex ?? this.myDeviceInfoIndex,
      myCameraIndex: myCameraIndex ?? this.myCameraIndex,
      sharedRunSessionId: sharedRunSessionId ?? this.sharedRunSessionId,
      expectedCameraCount: expectedCameraCount ?? this.expectedCameraCount,
      isRecordingEnabled: isRecordingEnabled ?? this.isRecordingEnabled,
      runnerSource: runnerSource ?? this.runnerSource,
      runnerId: runnerId ?? this.runnerId,
      runnerName: runnerName ?? this.runnerName,
      fps: fps ?? this.fps,
      note: note ?? this.note,
    );
  }
}
