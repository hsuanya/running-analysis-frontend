enum RecordRole { master, slave, none }

enum RecordStatus { idle, connecting, ready, recording, uploading, finished }

class RecordMember {
  final String id;
  final int? cameraIndex;
  final bool isReady;

  RecordMember({required this.id, this.cameraIndex, this.isReady = false});

  factory RecordMember.fromJson(Map<String, dynamic> json) {
    return RecordMember(
      id: json['id'],
      cameraIndex: json['cameraIndex'],
      isReady: json['isReady'] ?? false,
    );
  }
}

enum RecordMessageType {
  createRoom,
  joinRoom,
  roomStatus,
  startRecording,
  stopRecording,
  uploadComplete,
  updateReady,
  error,
}

class RecordMessage {
  final RecordMessageType type;
  final Map<String, dynamic> data;

  RecordMessage({required this.type, required this.data});

  factory RecordMessage.fromJson(Map<String, dynamic> json) {
    return RecordMessage(
      type: RecordMessageType.values.byName(json['type']),
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'data': data};
}
