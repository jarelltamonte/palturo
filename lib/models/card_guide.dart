import 'package:flutter/widgets.dart';

/// Parts of a For You card that the first-card guide can spotlight.
enum CardGuideTarget {
  card,
  skill,
  name,
  note,
  language,
  learningStyle,
  schedule,
  actions,
}

/// Optional keys attached by [PersonCardOverlay] so the guide can measure the
/// real widget positions without coupling the card to the overlay.
class CardGuideKeys {
  const CardGuideKeys({
    this.card,
    this.skill,
    this.name,
    this.note,
    this.language,
    this.learningStyle,
    this.schedule,
    this.actions,
  });

  final GlobalKey? card;
  final GlobalKey? skill;
  final GlobalKey? name;
  final GlobalKey? note;
  final GlobalKey? language;
  final GlobalKey? learningStyle;
  final GlobalKey? schedule;
  final GlobalKey? actions;

  GlobalKey? forTarget(CardGuideTarget target) => switch (target) {
    CardGuideTarget.card => card,
    CardGuideTarget.skill => skill,
    CardGuideTarget.name => name,
    CardGuideTarget.note => note,
    CardGuideTarget.language => language,
    CardGuideTarget.learningStyle => learningStyle,
    CardGuideTarget.schedule => schedule,
    CardGuideTarget.actions => actions,
  };
}

class CardGuideStep {
  const CardGuideStep({
    required this.target,
    required this.title,
    required this.body,
  });

  final CardGuideTarget target;
  final String title;
  final String body;
}
