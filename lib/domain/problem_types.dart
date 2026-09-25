import 'package:flutter/material.dart';

/// The five problem areas the book organises the mental game around.
enum ProblemType {
  greed('Greed', Icons.trending_up, Color(0xFFF2A516), []),
  fear('Fear', Icons.warning_amber_rounded, Color(0xFF8E6BD8), [
    'Fear of missing out (FOMO)',
    'Fear of losing',
    'Fear of mistakes',
    'Fear of failure',
  ]),
  tilt('Tilt', Icons.local_fire_department, Color(0xFFE0524D), [
    'Hating to lose',
    'Mistake tilt',
    'Injustice tilt',
    'Revenge trading',
    'Entitlement tilt',
  ]),
  confidence('Confidence', Icons.shield_outlined, Color(0xFF3E8EDE), [
    'Overconfidence',
    'Lack of confidence',
    'Perfectionism',
    'Desperation',
    'Hope and wishing',
  ]),
  discipline('Discipline', Icons.schedule, Color(0xFF3FAE6A), [
    'Impatience',
    'Boredom',
    'Overly results-oriented',
    'Distractibility',
    'Laziness',
    'Procrastination',
  ]);

  const ProblemType(this.label, this.icon, this.color, this.subtypes);

  final String label;
  final IconData icon;
  final Color color;
  final List<String> subtypes;

  static ProblemType? tryParse(Object? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// The details worth capturing around a trading mistake when mapping a
/// pattern (Ch. 2).
enum PatternField {
  trigger('Trigger', 'What set it off? A loss, a big winner, a missed move…'),
  thoughts('Thoughts', 'What went through your mind?'),
  emotions('Emotions', 'What did you feel, and how strongly?'),
  saidOutLoud('Things said out loud', 'Anything you muttered or shouted?'),
  behaviors('Behaviors', 'Body, posture, how you sat at the screen…'),
  actions('Actions', 'What did you actually do? Checked PnL, changed chart…'),
  decisionChange('Change in decision-making',
      'How did your process differ from normal?'),
  perceptionChange('Change in market perception',
      'How did your read of the market or your positions shift?'),
  mistake('Trading mistake', 'The execution error that resulted.');

  const PatternField(this.label, this.hint);

  final String label;
  final String hint;

  static PatternField? tryParse(Object? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}
