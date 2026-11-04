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
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ChatPrivacyService.instance;
    if (service.loaded) {
      if (_error != null && mounted) {
        setState(() => _error = null);
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await service.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : "Couldn't load chat privacy. Please try again.";
    });
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
          if (_loading || service.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null || !service.loaded) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? "Couldn't load chat privacy. Please try again.",
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
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _switch(
                context,
                title: 'Show when I am online',
                subtitle:
                    'When off, Pals cannot see when you are online or were last active.',
                value: service.presenceEnabled,
                onChanged: (value) {
                  Haptics.selection();
                  _save(presence: value);
                },
              ),
              _switch(
                context,
                title: 'Typing indicators',
                subtitle: 'When off, you do not send typing status to Pals.',
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
                    'When off, Pals cannot see when you have read their messages.',
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
