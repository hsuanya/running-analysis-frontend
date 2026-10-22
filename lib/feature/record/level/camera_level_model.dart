class CameraLevelData {
  /// 左右水平傾角 (Roll) in degrees
  /// 0.0 = 完美水平
  /// 正值 = 順時針傾斜（右側下沉）
  /// 負值 = 逆時針傾斜（左側下沉）
  final double roll;

  /// 前後仰俯角 (Pitch) in degrees
  /// 0.0 = 與地面垂直（立姿面向跑道）
  /// 正值 = 向後仰（朝向天空）
  /// 負值 = 向前傾（朝向地面）
  final double pitch;

  /// 是否接近水平（預設誤差在 ±0.8° 內）
  final bool isLevel;

  /// 感測器是否有實際有效數據 (桌機/無陀螺儀時為 false)
  final bool isAvailable;

  const CameraLevelData({
    this.roll = 0.0,
    this.pitch = 0.0,
    this.isLevel = false,
    this.isAvailable = false,
  });

  @override
  String toString() =>
      'CameraLevelData(roll: ${roll.toStringAsFixed(1)}°, pitch: ${pitch.toStringAsFixed(1)}°, isLevel: $isLevel, isAvailable: $isAvailable)';
}
