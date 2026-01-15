import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/backend/backend_interface.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/utils/api.dart';

class UploadSeperatelyState {
  final String? thumbnail;
  final String? tempVideoId;
  final bool isUploading;
  final String? error;

  UploadSeperatelyState({
    required this.thumbnail,
    required this.tempVideoId,
    this.isUploading = false,
    this.error,
  });

  factory UploadSeperatelyState.initial() =>
      UploadSeperatelyState(thumbnail: null, tempVideoId: null);

  UploadSeperatelyState copyWith({
    String? thumbnail,
    String? tempVideoId,
    bool? isUploading,
    String? error,
  }) {
    return UploadSeperatelyState(
      thumbnail: thumbnail ?? this.thumbnail,
      tempVideoId: tempVideoId ?? this.tempVideoId,
      isUploading: isUploading ?? this.isUploading,
      error: error,
    );
  }
}

class UploadSeperatelyController extends StateNotifier<UploadSeperatelyState> {
  final BackendInterface backend;

  UploadSeperatelyController(this.backend)
    : super(UploadSeperatelyState.initial());

  Future<void> uploadVideo(int index, UploadVideoFile file) async {
    state = state.copyWith(isUploading: true, error: null);

    try {
      final tempVideoId = await backend.uploadVideo(index, file);
      final thumbnailUrl = API.getTempVideoThumbnail(tempVideoId)[1];
      state = state.copyWith(
        thumbnail: thumbnailUrl,
        tempVideoId: tempVideoId,
        isUploading: false,
      );
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
    }
  }

  void resetState() {
    state = UploadSeperatelyState.initial();
  }
}

final uploadSeperatelyControllerProvider =
    StateNotifierProvider.autoDispose<
      UploadSeperatelyController,
      UploadSeperatelyState
    >((ref) {
      final backend = ref.watch(backendProvider);
      return UploadSeperatelyController(backend);
    });
