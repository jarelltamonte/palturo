import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// In-chat search over currently loaded messages.
///
/// Owns its own controller so the dismissal animation can never touch a
/// disposed controller. Returns the chosen message through `Navigator.pop`.
class ChatSearchSheet extends StatefulWidget {
  const ChatSearchSheet({
    super.key,
    required this.messages,
    required this.formatTime,
  });

  final List<Map<String, dynamic>> messages;
  final String Function(Map<String, dynamic>) formatTime;

  @override
  State<ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends State<ChatSearchSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final matches =
        query.isEmpty
            ? const <Map<String, dynamic>>[]
            : widget.messages
                .where((message) {
                  final body = (message['body'] ?? '').toString().toLowerCase();
                  return body.contains(query);
                })
                .toList(growable: false);
    final textColor = Theme.of(context).colorScheme.secondary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search this chat',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.mutedSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (query.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Type to search messages.',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                    ),
                  ),
                )
              else if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No messages found.',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final message = matches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (message['body'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.regularText.copyWith(
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          widget.formatTime(message),
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, message),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
