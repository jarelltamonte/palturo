import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/person_card.dart';

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

class BlockListPage extends StatelessWidget {
  const BlockListPage({super.key});

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
          'Block list',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 16,
          ),
        ),
      ),
      body: ValueListenableBuilder<List<Person>>(
        valueListenable: BlockedUsers.notifier,
        builder: (context, blocked, _) {
          if (blocked.isEmpty) {
            return _buildEmptyState(textTheme);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: blocked.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: textTheme.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final person = blocked[index];
              return _BlockedTile(
                person: person,
                onUnblock: () {
                  BlockedUsers.unblock(person.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You unblocked ${person.name}')),
                  );
                },
              );
            },
          );
        },
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
    final textColor = Theme.of(context).colorScheme.secondary;
    final photo = person.photoUrls.isNotEmpty ? person.photoUrls.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Icon(Icons.person, color: Colors.grey[600], size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  person.skillName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.regularText.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: textColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Unblock',
              style: AppTextStyles.regularText.copyWith(
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}