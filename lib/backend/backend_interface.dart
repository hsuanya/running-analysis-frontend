import 'package:frontend/entities/graph_data.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/entities/unanalyzed_run_session_info.dart';
import 'package:frontend/entities/upload_seperately_status.dart';
import 'package:frontend/entities/upload_video_file.dart';
import 'package:frontend/entities/run_session_info.dart';

abstract class BackendInterface {
  Future<List<RunnerInfo>> getRunners();
  Future<List<GraphData>> getGraphData(String runSessionId);
  Future<RunSessionInfo> getRunSessionInfo(String runSessionId);
  Future<List<RunSessionInfo>> getRunnerHistory(String runnerId);
  Future<List<UnanalyzedRunSessionInfo>> getRunnerUnanalyzedHistory(
    String runnerId,
  );

  Future<String> addRunner(String name);
  Future<String> uploadAllInfo(
    String runnerId,
    DateTime date,
    int cameraCount,
    int fps,
    String note,
    List<String> tempVideoIds,
  );
  Future<UploadSeperatelyStatus> uploadSeperatelyNew(
    String runnerId,
    DateTime date,
    int cameraCount,
    int fps,
    String note,
    int cameraIndex,
    String tempVideoId,
  );
  Future<UploadSeperatelyStatus> uploadSeperatelySelect(
    String runnerId,
    String runSessionId,
    int cameraIndex,
    String tempVideoId,
  );
  Future<String> uploadVideo(int index, UploadVideoFile file);
}
