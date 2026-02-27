import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/home_page.dart';
import 'package:frontend/feature/playback/playback_page.dart';
import 'package:frontend/feature/upload/upload_page.dart';
import 'package:frontend/feature/record/record_page.dart';
import 'package:frontend/feature/splash/splash_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

enum AppRoute { playback, upload, record }

Page<dynamic> _buildFadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
          ),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: kIsWeb ? '/playback' : '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            _buildFadePage(state, const SplashPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => HomePage(child: child),
        routes: [
          GoRoute(
            path: '/playback',
            name: AppRoute.playback.name,
            pageBuilder: (context, state) {
              final runnerId = state.uri.queryParameters['runnerId'];
              final videoId = state.uri.queryParameters['videoId'];
              return _buildFadePage(
                state,
                PlaybackPage(runnerId: runnerId, videoId: videoId),
              );
            },
          ),
          GoRoute(
            path: '/upload',
            name: AppRoute.upload.name,
            pageBuilder: (context, state) {
              return _buildFadePage(state, const UploadPage());
            },
          ),
          GoRoute(
            path: '/record',
            name: AppRoute.record.name,
            pageBuilder: (context, state) {
              return _buildFadePage(state, const RecordPage());
            },
          ),
        ],
      ),
    ],
  );
});
