import 'package:flutter/material.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    ActivityService.instance.markRead();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await MatchApi.listNotifications(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t load activity.\nPlease check your connection.';
      });
    }
  }

  ({IconData icon, String title, String body}) _presentation(String kind) {
    switch (kind) {
      case 'connection_request':
        return (
          icon: Icons.person_add_alt_1_outlined,
          title: 'New connection request',
          body: 'Someone wants to exchange skills with you.',
        );
      case 'request_accepted':
        return (
          icon: Icons.check_circle_outline,
          title: 'Request accepted',
          body: 'You can start chatting with your new pal.',
        );
      case 'request_declined':
        return (
          icon: Icons.info_outline,
          title: 'Request declined',
          body: 'This request did not move forward.',
        );
      case 'feedback_ready':
        return (
          icon: Icons.rate_review_outlined,
          title: 'Feedback is ready',
          body: 'Your 15-message exchange can now be rated.',
        );
      default:
        return (
          icon: Icons.notifications_none,
          title: 'Activity',
          body: 'There is a new update in PalTuro.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
        ),
        title: Text(
          'Activity',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : _items.isEmpty
              ? Center(
                child: Text(
                  'No activity yet',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final kind = (item['kind'] ?? '').toString();
                  final view = _presentation(kind);
                  final created = DateTime.tryParse(
                    item['created_at']?.toString() ?? '',
                  );
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            view.icon,
                            size: 19,
                            color: AppColors.accentText(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.title,
                                style: AppTextStyles.boldText.copyWith(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                view.body,
                                style: AppTextStyles.regularText.copyWith(
                                  color: textColor.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (created != null)
                          Text(
                            ChatTimeFormatter.formatChatListTime(created),
                            style: AppTextStyles.regularText.copyWith(
                              color: AppColors.mutedText(context),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
