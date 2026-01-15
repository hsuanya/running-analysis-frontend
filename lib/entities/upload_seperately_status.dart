class UploadSeperatelyStatus {
  String runnerId;
  String runSessionId;
  bool isAllUploaded;
  List<int> unuploadedCameraIndexes;

  UploadSeperatelyStatus({
    required this.runnerId,
    required this.runSessionId,
    required this.isAllUploaded,
    required this.unuploadedCameraIndexes,
  });

  factory UploadSeperatelyStatus.fromJson(Map<String, dynamic> json) {
    return UploadSeperatelyStatus(
      runnerId: json['runnerId'],
      runSessionId: json['runSessionId'],
      isAllUploaded: json['isAllUploaded'],
      unuploadedCameraIndexes: List<int>.from(json['unuploadedCameraIndexes']),
    );
  }
}
