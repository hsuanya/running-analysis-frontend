import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/entities/run_session_info.dart';

final List<RunnerInfo> kRunners = [
  RunnerInfo(name: 'Player 1', id: '1', lastVideoId: 'videoId0'),
  RunnerInfo(name: 'Player 2', id: '2', lastVideoId: ''),
  RunnerInfo(name: 'Player 3', id: '3', lastVideoId: ''),
  RunnerInfo(name: 'Player 4', id: '4', lastVideoId: ''),
  RunnerInfo(name: 'Player 5', id: '5', lastVideoId: ''),
];

final List<RunSessionInfo> kVideos = [
  RunSessionInfo(
    runSessionId: 'videoId0',
    runnerId: '1',
    runnerName: 'Player 1',
    date: DateTime.now(),
    cameraCount: 5,
    fps: 60,
    avgVelocity: 0,
    totalTime: 0,
    note: 'note',
    status: 'done',
    progress: 100,
  ),
  RunSessionInfo(
    runSessionId: 'videoId1',
    runnerId: '1',
    runnerName: 'Player 1',
    date: DateTime.parse('2025-10-27 10:04:00'),
    cameraCount: 5,
    fps: 60,
    avgVelocity: 0,
    totalTime: 0,
    note: 'note',
    status: 'done',
    progress: 100,
  ),
];
