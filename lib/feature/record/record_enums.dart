enum RecordRole { master, slave, none }

enum RecordStatus { idle, connecting, ready, recording, uploading, finished }

class RecordMember {
  final String id;
  final int? cameraIndex;
  final bool isReady;
  final bool isMaster;
  final String? cameraName;
  final String? cameraSpecs;

  RecordMember({
    required this.id,
    this.cameraIndex,
    this.isReady = false,
    this.isMaster = false,
    this.cameraName,
    this.cameraSpecs,
  });

  factory RecordMember.fromJson(Map<String, dynamic> json) {
    return RecordMember(
      id: json['id'],
      cameraIndex: json['cameraIndex'],
      isReady: json['isReady'] ?? false,
      isMaster: json['isMaster'] ?? false,
      cameraName: json['cameraName'],
      cameraSpecs: json['cameraSpecs'],
    );
  }
}

enum RecordMessageType {
  sync,
  createRoom,
  joinRoom,
  leaveRoom,
  roomStatus,
  startRecording,
  stopRecording,
  uploadComplete,
  updateReady,
  cameraPreview,
  error,
  requestControl,
  respondControlRequest,
  controlRequest,
  controlGranted,
  controlRevoked,
  controlRejected,
  notifyNotReady,
  kickMember,
  kicked,
  updateCameraInfo,
}

class RecordMessage {
  final RecordMessageType type;
  final Map<String, dynamic> data;

  RecordMessage({required this.type, required this.data});

  factory RecordMessage.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = RecordMessageType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => RecordMessageType.sync,
    );
    return RecordMessage(
      type: type,
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'data': data};
}
