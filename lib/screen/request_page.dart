import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/request_card.dart';

class ConnectionRequest {
  final String id;
  final String skillName;
  final String requesterName;
  final String schedule;
  final String language;
  final String learningStyle;
  final DateTime requestedAt;
  final String iconAsset;
  final String seekingLabel;

  const ConnectionRequest({
    required this.id,
    required this.skillName,
    required this.requesterName,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.requestedAt,
    this.iconAsset = 'assets/icons/rlearner.svg',
    this.seekingLabel = 'Seeking a learner in',
  });
}

String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  String _selectedSort = 'Newest first';

  final List<ConnectionRequest> _requests = [
    ConnectionRequest(
      id: '1',
      skillName: 'Parol Making',
      requesterName: 'RJ',
      schedule: 'Mon/Wed/Sat',
      language: 'English',
      learningStyle: 'Discussion',
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    ConnectionRequest(
      id: '2',
      skillName: 'Weaving Inabel',
      requesterName: 'Maria',
      schedule: 'Tue/Thu',
      language: 'Tagalog',
      learningStyle: 'Hands-on Practice',
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<ConnectionRequest> get _sortedRequests {
    final sorted = List<ConnectionRequest>.from(_requests);
    switch (_selectedSort) {
      case 'Newest first':
        sorted.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        break;
      case 'Oldest first':
        sorted.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
        break;
      case 'Alphabetically (A–Z)':
        sorted.sort((a, b) => a.requesterName.compareTo(b.requesterName));
        break;
      case 'Alphabetically (Z–A)':
        sorted.sort((a, b) => b.requesterName.compareTo(a.requesterName));
        break;
    }
    return sorted;
  }

  void _removeRequest(String id) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    final requests = _sortedRequests;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              'Requests',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _selectedSort = value;
                });
              },
              offset: const Offset(0, 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'Newest first',
                  child: _buildSortOption(
                      'Newest first', textTheme, primaryColor),
                ),
                PopupMenuItem<String>(
                  value: 'Oldest first',
                  child: _buildSortOption(
                      'Oldest first', textTheme, primaryColor),
                ),
                PopupMenuItem<String>(
                  value: 'Alphabetically (A–Z)',
                  child: _buildSortOption(
                      'Alphabetically (A–Z)', textTheme, primaryColor),
                ),
                PopupMenuItem<String>(
                  value: 'Alphabetically (Z–A)',
                  child: _buildSortOption(
                      'Alphabetically (Z–A)', textTheme, primaryColor),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 20, color: textTheme),
                  const SizedBox(width: 6),
                  Text(
                    'Sort by',
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: requests.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'They want to connect with you. Like back to start exchanging skills right away!',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            );
          }
          final request = requests[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RequestCard(
              skillName: request.skillName,
              requesterName: request.requesterName,
              schedule: request.schedule,
              language: request.language,
              learningStyle: request.learningStyle,
              timeAgo: timeAgo(request.requestedAt),
              iconAsset: request.iconAsset,
              seekingLabel: request.seekingLabel,
              onAccept: () => _removeRequest(request.id),
              onDecline: () => _removeRequest(request.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortOption(String option, Color textTheme, Color primaryColor) {
    final isSelected = _selectedSort == option;

    return Row(
      children: [
        SizedBox(
          width: 20,
          child: isSelected
              ? Icon(Icons.check, size: 18, color: primaryColor)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          option,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}