import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

enum PendingMessageStatus { sending, failed }

class PendingChatMessage {
  final String localId;
  final String body;
  final DateTime createdAt;
  final PendingMessageStatus status;

  const PendingChatMessage({
    required this.localId,
    required this.body,
    required this.createdAt,
    this.status = PendingMessageStatus.sending,
  });

  PendingChatMessage copyWith({PendingMessageStatus? status}) {
    return PendingChatMessage(
      localId: localId,
      body: body,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

class PendingMessageBubble extends StatelessWidget {
  final PendingChatMessage message;
  final VoidCallback? onRetry;

  const PendingMessageBubble({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failed = message.status == PendingMessageStatus.failed;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
              failed
                  ? AppColors.danger
                  : AppColors.primary.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: AppTextStyles.regularText.copyWith(
                color: failed ? Colors.white : Colors.black,
              ),
            ),
            if (message.status == PendingMessageStatus.sending) ...[
              const SizedBox(height: 4),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.black87,
                ),
              ),
            ] else if (failed) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Not sent',
                    style: AppTextStyles.regularText.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
