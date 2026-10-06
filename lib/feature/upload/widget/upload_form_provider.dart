import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/feature/upload/widget/upload_enums.dart';

class UploadFormData {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final int fps;
  final double trackWidth;
  final String note;

  UploadFormData({
    required this.selectedDate,
    required this.selectedTime,
    required this.fps,
    this.trackWidth = 1.22,
    required this.note,
  });

  UploadFormData copyWith({
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    int? fps,
    double? trackWidth,
    String? note,
  }) {
    return UploadFormData(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      fps: fps ?? this.fps,
      trackWidth: trackWidth ?? this.trackWidth,
      note: note ?? this.note,
    );
  }

  factory UploadFormData.initial() => UploadFormData(
    selectedDate: DateTime.now(),
    selectedTime: TimeOfDay.now(),
    fps: 60,
    trackWidth: 1.22,
    note: '',
  );
}

final uploadAllFormProvider = StateProvider.autoDispose<UploadFormData>(
  (ref) => UploadFormData.initial(),
);

final uploadSeperatelyFormProvider = StateProvider.autoDispose<UploadFormData>(
  (ref) => UploadFormData.initial(),
);

final uploadTypeProvider = StateProvider.autoDispose<UploadType>((ref) {
  return UploadType.all;
});

final runnerSourceProvider = StateProvider.autoDispose<RunnerSource>((ref) {
  return RunnerSource.select;
});

final runnerNameInputProvider = StateProvider.autoDispose<String>((ref) {
  return '';
});

final uploadSeparatelyTypeProvider = StateProvider.autoDispose<SperatedType>((ref) {
  return SperatedType.newOne;
});
