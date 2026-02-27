import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:frontend/utils/router.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';

class HomePage extends StatefulWidget {
  final Widget child;
  const HomePage({super.key, required this.child});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _controller.selectedIndex == 0
              ? "回放"
              : _controller.selectedIndex == 1
              ? "上傳"
              : "錄影",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              backgroundColor: Color.fromARGB(255, 121, 169, 234),
            )
          : null,
    );
  }
}
