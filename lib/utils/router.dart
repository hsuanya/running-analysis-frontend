import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/home_page.dart';
import 'package:frontend/feature/playback/playback_page.dart';
import 'package:frontend/feature/upload/upload_page.dart';
import 'package:go_router/go_router.dart';

enum AppRoute { playback, upload }

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/playback',
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomePage(child: child),
        routes: [
          GoRoute(
            path: '/playback',
            name: AppRoute.playback.name,
            pageBuilder: (context, state) {
              final runnerId = state.uri.queryParameters['runnerId'];
              final videoId = state.uri.queryParameters['videoId'];
              return NoTransitionPage(
                child: PlaybackPage(runnerId: runnerId, videoId: videoId),
              );
            },
          ),
          GoRoute(
            path: '/upload',
            name: AppRoute.upload.name,
            pageBuilder: (context, state) {
              return NoTransitionPage(child: const UploadPage());
            },
          ),
        ],
      ),
    ],
  );
});
