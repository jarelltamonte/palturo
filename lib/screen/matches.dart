import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/screen/users_dump.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;

enum RoleFilter { all, learner, mentor }

class Matches extends StatefulWidget {
  const Matches({super.key});

  @override
  State<Matches> createState() => _MatchesState();
}

class _MatchesState extends State<Matches> {
  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  static const List<Color> _avatarColors = [
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF7986CB),
    Color(0xFF4FC3F7),
    Color(0xFF4DB6AC),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFA1887F),
  ];

  final Map<String, GlobalKey> _sectionKeys = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String? _activeLetter;
  bool _isSearching = false;
  String _query = '';
  RoleFilter _roleFilter = RoleFilter.all;

  final List<MatchedUser> _pals = [...dumpUsers];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  List<MatchedUser> _filteredPals() {
    final q = _query.trim().toLowerCase();
    return _pals.where((pal) {
      final matchesRole = switch (_roleFilter) {
        RoleFilter.all => true,
        RoleFilter.learner => pal.role == PersonRole.learner,
        RoleFilter.mentor => pal.role == PersonRole.mentor,
      };
      final matchesQuery = q.isEmpty || pal.name.toLowerCase().contains(q);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Map<String, List<MatchedUser>> _groupedPals(List<MatchedUser> pals) {
    final sorted = [...pals]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final Map<String, List<MatchedUser>> grouped = {};
    for (final pal in sorted) {
      final letter = pal.name[0].toUpperCase();
      grouped.putIfAbsent(letter, () => []).add(pal);
    }
    return grouped;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _colorFor(String name) {
    return _avatarColors[name.hashCode.abs() % _avatarColors.length];
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _stopSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  void _jumpToLetter(String letter, Map<String, List<MatchedUser>> grouped) {
    final startIndex = _alphabet.indexOf(letter);
    String? target;
    for (int i = startIndex; i < _alphabet.length; i++) {
      if (grouped.containsKey(_alphabet[i])) {
        target = _alphabet[i];
        break;
      }
    }
    if (target == null) {
      for (int i = startIndex; i >= 0; i--) {
        if (grouped.containsKey(_alphabet[i])) {
          target = _alphabet[i];
          break;
        }
      }
    }
    if (target == null) return;

    setState(() => _activeLetter = target);

    final context = _sectionKeys[target]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: Duration.zero,
      );
    }
  }

  void _handleAction(String action, MatchedUser pal) {
    if (action == 'unmatch') {
      setState(() => _pals.removeWhere((p) => p.id == pal.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You unmatched ${pal.name}')),
      );
    } else if (action == 'report') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You reported ${pal.name}')),
      );
    }
  }

  Widget _sheetSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: AppTextStyles.regularText.copyWith(
        color: textColor.withValues(alpha: 0.6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color primaryColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : textColor.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: selected ? Colors.black : textColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final bgColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.secondary;
    RoleFilter draftRole = _roleFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: AppTextStyles.boldText.copyWith(
                              color: textColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setModalState(() => draftRole = RoleFilter.all),
                          child: Text(
                            'Reset',
                            style: AppTextStyles.regularText.copyWith(
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sheetSectionLabel('Role', textColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'All',
                          draftRole == RoleFilter.all,
                          () => setModalState(() => draftRole = RoleFilter.all),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Learner',
                          draftRole == RoleFilter.learner,
                          () => setModalState(
                              () => draftRole = RoleFilter.learner),
                          AppColors.primary,
                          textColor,
                        ),
                        _filterChip(
                          'Mentor',
                          draftRole == RoleFilter.mentor,
                          () => setModalState(
                              () => draftRole = RoleFilter.mentor),
                          AppColors.primary,
                          textColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetSectionLabel('Skills', textColor),
                    const SizedBox(height: 8),
                    Text(
                      'Coming soon',
                      style: AppTextStyles.regularText.copyWith(
                        color: textColor.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() => _roleFilter = draftRole);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPalTile(MatchedUser pal, Color textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _colorFor(pal.name),
            backgroundImage: pal.avatarImage,
            child:
                pal.avatarImage == null
                    ? Text(
                      _initials(pal.name),
                      style: AppTextStyles.regularText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.regularText.copyWith(color: textTheme),
                ),
                const SizedBox(height: 2),
                SkillTag(skillName: pal.skillName, role: pal.role),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: textTheme),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) => _handleAction(value, pal),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'unmatch',
                child: Row(
                  children: [
                    const Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Unmatch',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Report',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlphabetIndex(
    Map<String, List<MatchedUser>> grouped,
    Color textTheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final letterHeight =
            (constraints.maxHeight / _alphabet.length).clamp(12.0, 20.0);
        final totalHeight = letterHeight * _alphabet.length;

        void handleOffset(double dy) {
          final index =
              (dy / letterHeight).floor().clamp(0, _alphabet.length - 1);
          _jumpToLetter(_alphabet[index], grouped);
        }

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => handleOffset(details.localPosition.dy),
            onVerticalDragStart: (details) =>
                handleOffset(details.localPosition.dy),
            onVerticalDragUpdate: (details) =>
                handleOffset(details.localPosition.dy),
            onTapUp: (_) => setState(() => _activeLetter = null),
            onVerticalDragEnd: (_) => setState(() => _activeLetter = null),
            onVerticalDragCancel: () => setState(() => _activeLetter = null),
            child: SizedBox(
              width: 28,
              height: totalHeight,
              child: Column(
                children: _alphabet.map((letter) {
                  final hasItems = grouped.containsKey(letter);
                  final isActive = _activeLetter == letter;
                  return SizedBox(
                    height: letterHeight,
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : textTheme.withValues(
                                  alpha: hasItems ? 0.9 : 0.3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 40,
              color: textTheme.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No pals found',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgTheme = Theme.of(context).colorScheme.surface;
    final textTheme = Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    final filtered = _filteredPals();
    final grouped = _groupedPals(filtered);

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: _isSearching
            ? Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: textTheme.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: textTheme.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (value) => setState(() => _query = value),
                        textInputAction: TextInputAction.search,
                        style: AppTextStyles.regularText
                            .copyWith(color: textTheme),
                        cursorColor: primaryColor,
                        decoration: InputDecoration(
                          hintText: 'Search pals',
                          hintStyle: AppTextStyles.regularText.copyWith(
                            color: textTheme.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(
                          Icons.cancel,
                          size: 18,
                          color: textTheme.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 12,
                      bottom: 12,
                      right: 24,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: textTheme,
                      size: 16,
                    ),
                  ),
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  TextButton(
                    onPressed: _stopSearch,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(CupertinoIcons.search, color: textTheme),
                    onPressed: _startSearch,
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.tune, color: textTheme),
                      onPressed: _showFilterSheet,
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Your Pals',
                        style: AppTextStyles.headingText
                            .copyWith(color: textTheme),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 4),
                      child: Text(
                        '${filtered.length} matches',
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty) _buildEmptyState(textTheme),
                    for (final entry in grouped.entries) ...[
                      Padding(
                        key: _sectionKeys.putIfAbsent(
                            entry.key, () => GlobalKey()),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          entry.key,
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final pal in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          child: _buildPalTile(pal, textTheme),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildAlphabetIndex(grouped, textTheme),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}