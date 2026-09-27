import 'package:flutter/material.dart';
import 'package:palturo/screen/card/person_card.dart';

class RequestDetailDialog extends StatelessWidget {
  final Person person;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RequestDetailDialog({
    super.key,
    required this.person,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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