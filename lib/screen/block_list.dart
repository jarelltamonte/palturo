import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/services/match_api.dart';

/// In-memory helpers kept for transitional callers; blocks are persisted
/// through MatchApi.blockUser / unblockUser (DEV-11 resolved).
class BlockedUsers {
  BlockedUsers._();

  static final ValueNotifier<List<Person>> notifier =
      ValueNotifier<List<Person>>([]);

  static bool isBlocked(String id) =>
      notifier.value.any((person) => person.id == id);

  static void block(Person person) {
    if (isBlocked(person.id)) return;
    notifier.value = [...notifier.value, person];
  }

  static void unblock(String id) {
    notifier.value = notifier.value.where((p) => p.id != id).toList();
  }
}

/// Live blocked list from the `blocks` table (FR-15).
class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});

  @override
  State<BlockListPage> createState() => _BlockListPageState();
}

class _BlockListPageState extends State<BlockListPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _blocked = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await MatchApi.getBlockList();
      if (!mounted) return;
      setState(() {
        _blocked = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _unblock(Map<String, dynamic> entry) async {
    final id = entry['blocked_id'] as String? ?? '';
    final name = entry['name'] as String? ?? 'user';
    try {
      await MatchApi.unblockUser(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You unblocked $name')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unblock failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textTheme, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Blocked Users',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 16,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(textTheme)
              : _blocked.isEmpty
                  ? _buildEmptyState(textTheme)
                  : _buildList(textTheme),
    );
  }

  Widget _buildList(Color textTheme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _blocked.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: textTheme.withValues(alpha: 0.1),
      ),
      itemBuilder: (context, index) {
        final entry = _blocked[index];
        final person = Person(
          id: entry['blocked_id'] as String? ?? '',
          name: entry['name'] as String? ?? '',
          schedule: '',
          language: '',
          learningStyle: '',
          skillName: '',
          role: PersonRole.learner,
          photoUrls: [entry['avatar_url'] as String?],
        );
        return _BlockedTile(
          person: person,
          onUnblock: () => _unblock(entry),
        );
      },
    );
  }

  Widget _buildErrorState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Couldnâ€™t load blocked users.',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/empty.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              'No blocked users',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedTile extends StatelessWidget {
  final Person person;
  final VoidCallback onUnblock;

  const _BlockedTile({required this.person, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            backgroundImage:
                person.photoUrls[0] == null ? null : NetworkImage(person.photoUrls[0]!),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.name,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              foregroundColor: textTheme,
              side: BorderSide(color: textTheme.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Unblock',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
