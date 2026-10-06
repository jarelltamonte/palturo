import 'package:flutter/material.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';

class RequestDetailDialog extends StatelessWidget {
  final Person person;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onBlock;
  final ValueChanged<String>? onReport;

  const RequestDetailDialog({
    super.key,
    required this.person,
    required this.onAccept,
    required this.onDecline,
    this.onBlock,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final blockCallback = onBlock;
    final reportCallback = onReport;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SizedBox(
        width: screenSize.width - 40,
        height: screenSize.height * 0.75,
        child: Stack(
          children: [
            PersonCardOverlay(
              person: person,
              skipLabel: 'Decline',
              addLabel: 'Accept',
              onBlock: blockCallback == null
                  ? null
                  : () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Block',
                        message:
                            '${person.name} won’t be able to find or message you. You can unblock them anytime in Settings.',
                        confirmLabel: 'Block',
                      );
                      if (!confirmed || !context.mounted) return;
                      Navigator.pop(context);
                      blockCallback();
                    },
              onReport: reportCallback == null
                  ? null
                  : () async {
                      final reason = await showReportReasonDialog(
                        context,
                        name: person.name,
                      );
                      if (reason == null || !context.mounted) return;
                      reportCallback(reason);
                    },
              onAdd: () {
                onAccept();
                Navigator.pop(context);
              },
              onSkip: () {
                onDecline();
                Navigator.pop(context);
              },
            ),
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}