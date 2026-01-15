import 'package:frontend/utils/net_utils.dart';

class API {
  static const baseUrl = "https://catslab.ee.ncku.edu.tw:9130/api";

  static List getRunner = [DioMethod.get, "$baseUrl/runner"];
  static List addRunner = [DioMethod.post, "$baseUrl/runner"];

  static List getRunnerHistory(String runnerId) => [
    DioMethod.get,
    "$baseUrl/runner/$runnerId/run_sessions",
  ];

  static List getRunnerUnanalyzedHistory(String runnerId) => [
    DioMethod.get,
    "$baseUrl/runner/$runnerId/run_sessions/unanalyzed",
  ];

  static List getRunSessionInfo(String runSessionId) => [
    DioMethod.get,
    "$baseUrl/run_session/$runSessionId",
  ];

  static List getGraphData(String runSessionId) => [
    DioMethod.get,
    "$baseUrl/run_session/$runSessionId/graphs",
  ];

  static List getRunSessionVideo(String runSessionId) => [
    DioMethod.get,
    "$baseUrl/run_session/$runSessionId/video",
  ];

  static List getTempVideoThumbnail(String tempVideoId) => [
    DioMethod.get,
    "$baseUrl/temp_video/$tempVideoId/thumbnail",
  ];

  static List uploadVideo(int index) => [
    DioMethod.post,
    "$baseUrl/temp_video/$index",
  ];

  static List uploadAllInfo = [DioMethod.post, "$baseUrl/upload_all_info"];

  static List uploadSeperatelyNew = [
    DioMethod.post,
    "$baseUrl/upload_seperately_new",
  ];

  static List uploadSeperatelySelect = [
    DioMethod.post,
    "$baseUrl/upload_seperately_select",
  ];
}
