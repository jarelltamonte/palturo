import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/preferences_service.dart';

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
  final ValueNotifier<int> _requestsRefresh = ValueNotifier<int>(0);

  final List<IconData> _navigationIcons = [
    CupertinoIcons.person_2,
    CupertinoIcons.compass,
    CupertinoIcons.chat_bubble,
    CupertinoIcons.tray,
    CupertinoIcons.person,
  ];

  final List<IconData> _selectedIcons = [
    CupertinoIcons.person_2_fill,
    CupertinoIcons.compass_fill,
    CupertinoIcons.chat_bubble_fill,
    CupertinoIcons.tray_fill,
    CupertinoIcons.person_fill,
  ];

  final List<String> _navigationLabels = [
    'For You',
    'Browse',
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
    RequestPage(refreshSignal: _requestsRefresh),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    Haptics.selection();
    if (index == 3) {
      _requestsRefresh.value++;
      ActivityService.instance.markRead();
    }
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
  void dispose() {
    _requestsRefresh.dispose();
    super.dispose();
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
        body: Stack(
          children: List.generate(_pages.length, (index) {
            final active = index == _selectedIndex;
            final reducedMotion = MediaQuery.disableAnimationsOf(context);
            return Positioned.fill(
              child: ExcludeFocus(
                excluding: !active,
                child: IgnorePointer(
                  ignoring: !active,
                  child: ExcludeSemantics(
                    excluding: !active,
                    child: AnimatedSlide(
                      duration: reducedMotion ? Duration.zero : AppMotion.base,
                      curve: Curves.easeOut,
                      offset:
                          active
                              ? Offset.zero
                              : Offset(
                                index < _selectedIndex ? -0.035 : 0.035,
                                0,
                              ),
                      child: AnimatedOpacity(
                        duration:
                            !active || reducedMotion
                                ? Duration.zero
                                : AppMotion.base,
                        curve: Curves.easeOut,
                        opacity: active ? 1 : 0,
                        child: TickerMode(
                          enabled: active,
                          child: _pages[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 20),
          child: _buildNavBar(),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ChatStateService.instance,
        ActivityService.instance,
      ]),
      builder: (context, _) {
        final badgesEnabled = PreferencesService.instance.notificationsEnabled;
        final requestUnread =
            badgesEnabled ? ActivityService.instance.unread : 0;
        return Container(
          height: 60,
          margin: const EdgeInsets.only(right: 16, left: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.elevatedSurface(context),
            border: Border.all(color: AppColors.border(context)),
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
              final activeColor = AppColors.accentText(context);
              final inactiveColor = AppColors.mutedText(context);
              final isChat = index == 2;
              final isRequests = index == 3;
              final unreadCount =
                  isChat
                      ? (badgesEnabled
                          ? ChatStateService.instance.totalUnreadCount
                          : 0)
                      : isRequests
                      ? requestUnread
                      : 0;

              return _NavItem(
                icon:
                    isSelected
                        ? _selectedIcons[index]
                        : _navigationIcons[index],
                label: _navigationLabels[index],
                color: isSelected ? activeColor : inactiveColor,
                selected: isSelected,
                onTap: () => _onItemTapped(index),
                unreadCount: unreadCount,
              );
            }),
          ),
        );
      },
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
  final bool selected;
  final int unreadCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.unreadCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _selectionScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.press);

    _selectionScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.selected && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final showBadge = widget.unreadCount > 0;
    final isRequests = widget.label == 'Requests';
    final unreadLabel =
        widget.unreadCount == 1
            ? (isRequests ? '1 unread update' : '1 unread message')
            : '${widget.unreadCount} unread ${isRequests ? 'updates' : 'messages'}';
    final semanticsLabel =
        showBadge ? '${widget.label}, $unreadLabel' : widget.label;

    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: semanticsLabel,
        excludeSemantics: true,
        onTap: _handleTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _selectionScale,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _selectionScale.value,
                        child: child,
                      );
                    },
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -8,
                      right: -12,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.unreadCount > 99
                              ? '99+'
                              : '${widget.unreadCount}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: widget.color,
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration:
                    MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppMotion.micro,
                width: widget.selected ? 5 : 0,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.accentText(context),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
