import 'stick_analyzer.dart';
import 'trigger_analyzer.dart';
import 'polling_analyzer.dart';

enum IssueSeverity { info, warning, critical }

class HealthIssue {
  const HealthIssue(this.severity, this.title, this.detail);

  final IssueSeverity severity;
  final String title;
  final String detail;
}

class ComponentScore {
  const ComponentScore(this.label, this.score, this.max);

  final String label;
  final double score;
  final double max;

  double get ratio => max == 0 ? 0 : score / max;
}

class HealthReport {
  const HealthReport({
    required this.score,
    required this.grade,
    required this.components,
    required this.issues,
  });

  final double score; // 0..100
  final String grade;
  final List<ComponentScore> components;
  final List<HealthIssue> issues;

  static const empty = HealthReport(
    score: 0,
    grade: '—',
    components: [],
    issues: [],
  );

  String get gradeLabel => switch (grade) {
    'A' => 'Excellent',
    'B' => 'Bon',
    'C' => 'Moyen',
    'D' => 'À vérifier',
    'E' => 'Défaillant',
    _ => 'Non évalué',
  };
}

/// Calcule un score /100 à partir des métriques mesurées.
///
/// Barème : boutons 25 · sticks 30 · gâchettes 20 · vibration 10 ·
/// fréquence/stabilité 15. Chaque anomalie est expliquée séparément.
class HealthScorer {
  const HealthScorer();

  HealthReport score({
    required StickMetrics leftStick,
    required StickMetrics rightStick,
    required TriggerMetrics leftTrigger,
    required TriggerMetrics rightTrigger,
    PollingMetrics polling = PollingMetrics.empty,
    int buttonsTested = 0,
    int buttonsFailed = 0,
    bool? leftMotorOk,
    bool? rightMotorOk,
  }) {
    final issues = <HealthIssue>[];

    // --- Boutons (25) ---
    var buttonScore = 25.0;
    if (buttonsTested > 0) {
      buttonScore = 25.0 * (1 - (buttonsFailed / buttonsTested));
      if (buttonsFailed > 0) {
        issues.add(HealthIssue(
          IssueSeverity.critical,
          '$buttonsFailed bouton(s) défaillant(s)',
          'Sur $buttonsTested testés. Vérifie la nappe et le nettoyage des contacts.',
        ));
      }
    } else {
      buttonScore = 18;
      issues.add(const HealthIssue(
        IssueSeverity.info,
        'Boutons non testés',
        'Lance le test guidé pour compléter le score.',
      ));
    }

    // --- Sticks (30) ---
    final stickScores = [leftStick, rightStick].map(_stickScore).toList();
    final stickScore = stickScores.reduce((a, b) => a + b) / 2 * 30 / 100;

    for (final entry in [('gauche', leftStick), ('droit', rightStick)]) {
      final m = entry.$2;
      if (!m.hasData) {
        issues.add(HealthIssue(
          IssueSeverity.info,
          'Stick ${entry.$1} non analysé',
          'Fais tourner le stick 30 s dans le Stick Lab.',
        ));
        continue;
      }
      if (m.driftPercent > 2) {
        issues.add(HealthIssue(
          m.driftPercent > 5 ? IssueSeverity.critical : IssueSeverity.warning,
          'Drift stick ${entry.$1} : ${m.driftPercent.toStringAsFixed(1)} %',
          'Position de repos hors centre. Nettoyage du potentiomètre conseillé.',
        ));
      }
      if (m.circularityPercent > 0 && m.circularityPercent < 88) {
        issues.add(HealthIssue(
          IssueSeverity.warning,
          'Circularité stick ${entry.$1} : ${m.circularityPercent.toStringAsFixed(1)} %',
          'Course irrégulière : vérifie l\'usure du mécanisme ou du capuchon.',
        ));
      }
    }

    // --- Gâchettes (20) ---
    var triggerScore = 20.0;
    for (final entry in [('L2', leftTrigger), ('R2', rightTrigger)]) {
      final m = entry.$2;
      if (!m.hasData) {
        triggerScore -= 4;
        continue;
      }
      if (m.travelPercent < 95) {
        triggerScore -= 3;
        issues.add(HealthIssue(
          IssueSeverity.warning,
          '${entry.$1} : course ${m.travelPercent.toStringAsFixed(0)} %',
          'La gâchette n\'atteint pas sa valeur maximale. Poussière ou butée usée.',
        ));
      }
      if (m.linearityPercent < 85) {
        triggerScore -= 2;
        issues.add(HealthIssue(
          IssueSeverity.warning,
          '${entry.$1} : réponse non linéaire',
          'La pression ne suit pas une progression régulière.',
        ));
      }
    }
    triggerScore = triggerScore.clamp(0, 20);

    // --- Vibration (10) ---
    var vibrationScore = 10.0;
    if (leftMotorOk == null && rightMotorOk == null) {
      vibrationScore = 7;
      issues.add(const HealthIssue(
        IssueSeverity.info,
        'Vibration non testée',
        'Lance un motif dans le Vibration Studio.',
      ));
    } else {
      if (leftMotorOk == false) {
        vibrationScore -= 5;
        issues.add(const HealthIssue(
          IssueSeverity.critical,
          'Moteur gauche muet',
          'Le moteur fort ne répond pas : nappe ou moteur HS.',
        ));
      }
      if (rightMotorOk == false) {
        vibrationScore -= 5;
        issues.add(const HealthIssue(
          IssueSeverity.critical,
          'Moteur droit muet',
          'Le moteur fin ne répond pas : nappe ou moteur HS.',
        ));
      }
    }

    // --- Fréquence / stabilité (15) ---
    var pollingScore = 15.0;
    if (polling.hasData) {
      if (polling.jitterMs > 4) {
        pollingScore -= 6;
        issues.add(HealthIssue(
          IssueSeverity.warning,
          'Intervalles instables (${polling.jitterMs.toStringAsFixed(1)} ms)',
          'Jitter élevé : lien sans fil perturbé ou manette en économie d\'énergie.',
        ));
      }
      if (polling.stalls > polling.samples * 0.02) {
        pollingScore -= 4;
        issues.add(HealthIssue(
          IssueSeverity.warning,
          '${polling.stalls} micro-coupures détectées',
          'Des paquets manquent : rapproche la manette ou passe en USB.',
        ));
      }
    } else {
      pollingScore = 10;
    }

    final total = (buttonScore + stickScore + triggerScore + vibrationScore + pollingScore)
        .clamp(0.0, 100.0);

    final grade = switch (total) {
      >= 90 => 'A',
      >= 75 => 'B',
      >= 60 => 'C',
      >= 45 => 'D',
      _ => 'E',
    };

    issues.sort((a, b) => a.severity.index.compareTo(b.severity.index));

    return HealthReport(
      score: total,
      grade: grade,
      components: [
        ComponentScore('Boutons', buttonScore, 25),
        ComponentScore('Sticks', stickScore, 30),
        ComponentScore('Gâchettes', triggerScore, 20),
        ComponentScore('Vibration', vibrationScore, 10),
        ComponentScore('Fréquence', pollingScore, 15),
      ],
      issues: issues,
    );
  }

  double _stickScore(StickMetrics m) {
    if (!m.hasData) return 50;
    var score = 100.0;
    score -= (m.driftPercent * 6).clamp(0, 60);
    if (m.circularityPercent > 0) {
      score -= ((100 - m.circularityPercent) * 2.2).clamp(0, 30);
    }
    score -= (m.deadzonePercent - 6).clamp(0, 20) * 1.2;
    return score.clamp(0, 100);
  }
}
