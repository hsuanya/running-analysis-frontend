import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/auth/auth_provider.dart';
import 'package:frontend/feature/auth/auth_state.dart';
import 'package:frontend/utils/router.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';

class HomePage extends ConsumerStatefulWidget {
  final Widget child;
  const HomePage({super.key, required this.child});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  final SidebarXController _controller = SidebarXController(selectedIndex: 0);
  late TabController _tabController;
  bool _isSidebarOpen = false;
  bool _updatingFromRouter = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      if (_updatingFromRouter) return;
      final index = _controller.selectedIndex;

      if (_tabController.index != index) {
        _tabController.animateTo(index);
      }

      if (index == 0) context.goNamed(AppRoute.playback.name);
      if (index == 1) context.goNamed(AppRoute.upload.name);
      if (index == 2) context.goNamed(AppRoute.record.name);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final location = GoRouterState.of(context).uri.toString();
    _updatingFromRouter = true;
    if (location.startsWith('/playback')) {
      _controller.selectIndex(0);
      _tabController.index = 0;
    } else if (location.startsWith('/upload')) {
      _controller.selectIndex(1);
      _tabController.index = 1;
    } else if (location.startsWith('/record')) {
      _controller.selectIndex(2);
      _tabController.index = 2;
    }
    _isSidebarOpen = false;
    _updatingFromRouter = false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _controller.selectedIndex == 0
              ? "回放"
              : _controller.selectedIndex == 1
              ? "上傳"
              : "錄影",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 121, 169, 234),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(80),
        leading: isPortrait
            ? null
            : IconButton(
                color: Colors.white,
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              ),
        actions: [
          if (authState.status == AuthStatus.authenticated && authState.username != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    authState.username!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: '登出',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認登出'),
                  content: const Text('您確定要登出跑姿分析系統嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text('登出', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (!isPortrait)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _isSidebarOpen ? 100 : 0),
                child: SidebarX(
                  controller: _controller,
                  showToggleButton: false,
                  items: [
                    SidebarXItem(icon: Icons.play_arrow, label: "回放"),
                    SidebarXItem(icon: Icons.upload, label: "上傳"),
                    SidebarXItem(icon: Icons.videocam, label: "錄影"),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: isPortrait
          ? ConvexAppBar(
              controller: _tabController,
              onTap: (index) {
                _controller.selectIndex(index);
              },
              items: const [
                TabItem(icon: Icons.play_arrow),
                TabItem(icon: Icons.upload),
                TabItem(icon: Icons.videocam),
              ],
              backgroundColor: const Color.fromARGB(255, 121, 169, 234),
            )
          : null,
    );
  }
}
