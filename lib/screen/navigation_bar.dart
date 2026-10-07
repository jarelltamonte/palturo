import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';

import 'home_page.dart';
import 'explore_page.dart';
import 'chats_page.dart';
import 'profile_page.dart';
import 'request_page.dart';

class NavigationBarWidget extends StatefulWidget {
  const NavigationBarWidget({super.key});

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  static const int _exploreIndex = 1;
  int _selectedIndex = 0;

  final List<int> _tabHistory = [0];
  final GlobalKey<NavigatorState> _exploreNavKey = GlobalKey<NavigatorState>();

  final List<IconData> _navigationIcons = [
    CupertinoIcons.arrowtriangle_left,
    CupertinoIcons.compass,
    CupertinoIcons.chat_bubble,
    CupertinoIcons.heart,
    CupertinoIcons.person,
  ];

  final List<IconData> _selectedIcons = [
    CupertinoIcons.arrowtriangle_left_fill,
    CupertinoIcons.compass_fill,
    CupertinoIcons.chat_bubble_fill,
    CupertinoIcons.heart_fill,
    CupertinoIcons.person_fill,
  ];

  final List<String> _navigationLabels = [
    'People',
    'Explore',
    'Chats',
    'Requests',
    'Profile',
  ];

  late final List<Widget> _pages = [
    const HomePage(),
    _ExploreTab(
      navigatorKey: _exploreNavKey,
      isActive: () => _selectedIndex == _exploreIndex,
    ),
    ChatsPage(onStartSwiping: () => _onItemTapped(0)),
    const RequestPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index == _exploreIndex && _selectedIndex == _exploreIndex) {
      _exploreNavKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_selectedIndex == _exploreIndex &&
            (_exploreNavKey.currentState?.canPop() ?? false)) {
          _exploreNavKey.currentState?.pop();
          return;
        }

        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (_tabHistory.length > 1) {
          setState(() {
            _tabHistory.removeLast();
            _selectedIndex = _tabHistory.last;
          });
          return;
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(right: 16, left: 16, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navigationIcons.length, (index) {
          final isSelected = _selectedIndex == index;
          final activeColor = AppColors.primary;
          final inactiveColor = Colors.grey;

          return _NavItem(
            icon: isSelected ? _selectedIcons[index] : _navigationIcons[index],
            label: _navigationLabels[index],
            color: isSelected ? activeColor : inactiveColor,
            onTap: () => _onItemTapped(index),
          );
        }),
      ),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() isActive;

  const _ExploreTab({required this.navigatorKey, required this.isActive});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  bool _canPop = false;

  late final _ExploreObserver _observer = _ExploreObserver(_syncCanPop);

  void _syncCanPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canPop = widget.navigatorKey.currentState?.canPop() ?? false;
      if (canPop != _canPop) {
        setState(() => _canPop = canPop);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      enabled: _canPop && widget.isActive(),
      onPopWithResult: (result) {
        widget.navigatorKey.currentState?.pop();
      },
      child: Navigator(
        key: widget.navigatorKey,
        observers: [_observer],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => const ExplorePage(),
          );
        },
      ),
    );
  }
}

class _ExploreObserver extends NavigatorObserver {
  final VoidCallback onChanged;

  _ExploreObserver(this.onChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _jiggle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _jiggle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _jiggle,
              builder: (context, child) {
                return Transform.rotate(angle: _jiggle.value, child: child);
              },
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: widget.color,
                fontSize: 11,
                fontWeight:
                    widget.color == AppColors.primary
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
