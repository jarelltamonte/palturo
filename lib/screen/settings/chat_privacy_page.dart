import 'package:flutter/material.dart';
import 'package:palturo/services/chat_privacy_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/app_feedback.dart';

class ChatPrivacyPage extends StatefulWidget {
  const ChatPrivacyPage({super.key});

  @override
  State<ChatPrivacyPage> createState() => _ChatPrivacyPageState();
}

class _ChatPrivacyPageState extends State<ChatPrivacyPage> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ChatPrivacyService.instance.loadIfNeeded();
  }

  Future<void> _save({bool? presence, bool? typing, bool? readReceipts}) async {
    if (_saving) return;
    final service = ChatPrivacyService.instance;
    setState(() => _saving = true);
    final ok = await service.save(
      presence: presence ?? service.presenceEnabled,
      typing: typing ?? service.typingEnabled,
      readReceipts: readReceipts ?? service.readReceiptsEnabled,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showAppError(context, "Couldn't update chat privacy. Please try again.");
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
          'Chat privacy',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: ChatPrivacyService.instance,
        builder: (context, _) {
          final service = ChatPrivacyService.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _switch(
                context,
                title: 'Show when I am online',
                subtitle:
                    'Pals can see an online dot and your last active time.',
                value: service.presenceEnabled,
                onChanged: (value) {
                  Haptics.selection();
                  _save(presence: value);
                },
              ),
              _switch(
                context,
                title: 'Typing indicators',
                subtitle:
                    'Let Pals see when you are typing. Turning this off also hides their typing.',
                value: service.typingEnabled,
                onChanged: (value) {
                  Haptics.selection();
                  _save(typing: value);
                },
              ),
              _switch(
                context,
                title: 'Show read receipts',
                subtitle:
                    'Let Pals see when you have read their messages. Turning this off also hides their receipts.',
                value: service.readReceiptsEnabled,
                onChanged: (value) {
                  Haptics.selection();
                  _save(readReceipts: value);
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mutedSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.accentText(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Who can see my status: Pals only',
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _switch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTextStyles.regularText.copyWith(color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
        ),
      ),
      activeTrackColor: AppColors.primary,
      activeThumbColor: AppColors.white,
      inactiveTrackColor: AppColors.switchOffTrack(context),
      inactiveThumbColor: AppColors.white,
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }
}
