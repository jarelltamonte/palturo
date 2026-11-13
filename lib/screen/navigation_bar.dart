import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/services/app_shell_state.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/widgets/whats_new_sheet.dart';

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
    ProfilePage(onStartSwiping: () => _onItemTapped(0)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowWhatsNew(context);
    });
  }

  void _onItemTapped(int index) {
    Haptics.selection();
    AppShellState.instance.setSelectedTab(index);
    if (index == 3) {
      _requestsRefresh.value++;
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
    final desktop = MediaQuery.sizeOf(context).width >= 900;

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
          AppShellState.instance.setSelectedTab(_selectedIndex);
          return;
        }
      },
      child: desktop ? _buildDesktopShell(context) : _buildMobileShell(context),
    );
  }

  Widget _buildPageStack() {
    return Stack(
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
                          : Offset(index < _selectedIndex ? -0.035 : 0.035, 0),
                  child: AnimatedOpacity(
                    duration:
                        !active || reducedMotion
                            ? Duration.zero
                            : AppMotion.base,
                    curve: Curves.easeOut,
                    opacity: active ? 1 : 0,
                    child: TickerMode(enabled: active, child: _pages[index]),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMobileShell(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildPageStack(),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: _buildNavBar(),
      ),
    );
  }

  double get _desktopContentMaxWidth => switch (_selectedIndex) {
    0 => 760,
    1 => 1120,
    _ => 820,
  };

  Widget _buildDesktopShell(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: _selectedIndex,
            icons: _navigationIcons,
            selectedIcons: _selectedIcons,
            labels: _navigationLabels,
            onSelected: _onItemTapped,
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _desktopContentMaxWidth,
                  ),
                  child: SizedBox.expand(child: _buildPageStack()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ChatStateService.instance,
        NotificationService.instance,
      ]),
      builder: (context, _) {
        final badgesEnabled = PreferencesService.instance.notificationsEnabled;
        final requestUnread =
            badgesEnabled ? NotificationService.instance.unread : 0;
        final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
        return Container(
          height: largeText ? 74 : 60,
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
              final activeColor = AppColors.primary;
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

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.icons,
    required this.selectedIcons,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ChatStateService.instance,
        NotificationService.instance,
      ]),
      builder: (context, _) {
        final badgesEnabled = PreferencesService.instance.notificationsEnabled;
        final chatUnread =
            badgesEnabled ? ChatStateService.instance.totalUnreadCount : 0;
        final requestUnread =
            badgesEnabled ? NotificationService.instance.unread : 0;

        return Container(
          width: 252,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            border: Border(right: BorderSide(color: AppColors.border(context))),
          ),
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 46,
                    child: Image.asset(
                      isDark
                          ? 'assets/images/hlogo_white.png'
                          : 'assets/images/hlogo_black.png',
                      width: 138,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'SKILL EXCHANGE',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.accentText(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 34),
                  for (var index = 0; index < labels.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _DesktopNavItem(
                        icon:
                            selectedIndex == index
                                ? selectedIcons[index]
                                : icons[index],
                        label: labels[index],
                        selected: selectedIndex == index,
                        unreadCount:
                            index == 2
                                ? chatUnread
                                : index == 3
                                ? requestUnread
                                : 0,
                        onTap: () => onSelected(index),
                      ),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.smartphone_outlined,
                        size: 13,
                        color: AppColors.mutedText(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PalTuro is designed for mobile. This desktop layout is an adaptation.',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.black : Theme.of(context).colorScheme.secondary;
    final badgeColor = selected ? AppColors.black : AppColors.primary;
    final badgeText = selected ? AppColors.primary : AppColors.black;

    return Semantics(
      button: true,
      selected: selected,
      label: unreadCount > 0 ? '$label, $unreadCount unread' : label,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.boldText.copyWith(
                        color: foreground,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.boldText.copyWith(
                          color: badgeText,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
                      top: -6,
                      right: -10,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: widget.color,
                  fontSize: 12,
                  fontWeight:
                      widget.selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
