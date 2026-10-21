import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:pad_core/pad_core.dart';

import 'hardware_source.dart';
import 'link_sender.dart';

/// Une session d'utilisation réelle, gardée en mémoire pour l'accueil.
///
/// Rien n'est inventé : une session n'existe que si une manette a réellement
/// été lue assez longtemps.
class SessionRecord {
  const SessionRecord({
    required this.name,
    required this.startedAt,
    required this.duration,
    required this.score,
  });

  final String name;
  final DateTime startedAt;
  final Duration duration;
  final double score;
}

/// D'où viennent les entrées.
enum SourceMode {
  /// Décide tout seul : manette présente → réel, sinon démonstration.
  auto,

  /// Manette physique uniquement ; sans manette l'écran reste vide.
  real,

  /// Manette virtuelle, pour découvrir l'application sans matériel.
  demo,
}

/// Session de test : source d'état (matériel ou simulation), analyses et
/// batterie. L'UI n'écoute que ce notifier.
class PadSession extends ChangeNotifier {
  /// [simulate] reste accepté pour le code existant ; il équivaut à
  /// [mode] `demo` ou `real`.
  PadSession({SourceMode mode = SourceMode.auto, bool? simulate})
    : _mode = simulate == null
          ? mode
          : (simulate ? SourceMode.demo : SourceMode.real) {
    // Passer par une méthode : dans le corps d'un constructeur, le paramètre
    // nommé `simulate` masquerait le champ du même nom.
    _init();
  }

  void _init() {
    if (_mode == SourceMode.demo) {
      _seedBatteryHistory();
      _startSimulation();
      seedDemoAnalysis();
    } else {
      // Ni réel ni auto ne démarrent une simulation : tant qu'aucune manette
      // n'est confirmée, l'écran doit dire « aucune manette ».
      simulate = false;
    }
  }

  SourceMode _mode;

  /// Mode demandé par l'utilisateur (auto, réel, démo).
  SourceMode get mode => _mode;

  /// Vrai quand les entrées affichées sont générées. En mode auto, ce
  /// drapeau suit la présence réelle d'une manette : c'est lui qui dit à
  /// l'interface si ce qu'elle montre est vrai ou non.
  bool simulate = true;

  /// Vrai si la source est la manette physique.
  bool get isReal => !simulate;

  /// Actualisation automatique : sondage périodique des manettes et de la
  /// batterie. Actif par défaut ; le couper laisse le bouton manuel.
  bool autoRefresh = true;

  /// Dernière actualisation automatique, pour l'afficher dans les réglages.
  DateTime? lastAutoRefreshAt;

  void setAutoRefresh(bool value) {
    if (autoRefresh == value) return;
    autoRefresh = value;
    if (value) {
      lastAutoRefreshAt = DateTime.now();
      hardware?.watchDevices();
    } else {
      hardware?.stopWatchdog();
    }
    _notify();
  }

  /// Assez d'échantillons pour que le score de santé veuille dire quelque
  /// chose. En matériel, un score calculé sur zéro mesure serait trompeur.
  bool get hasMeasurements =>
      leftStick.sampleCount >= 30 || rightStick.sampleCount >= 30;

  bool _disposed = false;

  /// Historique des lectures réelles (les plus récentes d'abord).
  final List<SessionRecord> sessions = <SessionRecord>[];
  DateTime? _realSince;

  /// `notifyListeners` sûr : un minuteur peut se déclencher après la
  /// fermeture de l'écran.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Explication du dernier basculement (affichée dans l'interface).
  String? sourceNote;

  PadDevice? device;
  PadState state = PadState.idle;
  /// Dernière lecture connue. `percent == null` = inconnu, et l'interface
  /// l'affiche comme tel plutôt que d'inventer un chiffre.
  BatteryReading battery = BatteryReading(
    at: DateTime.now(),
    status: BatteryStatus.unknown,
    percent: null,
  );

  final StickAnalyzer leftStick = StickAnalyzer();
  final StickAnalyzer rightStick = StickAnalyzer();
  final TriggerAnalyzer leftTrigger = TriggerAnalyzer();
  final TriggerAnalyzer rightTrigger = TriggerAnalyzer();
  final PollingAnalyzer polling = PollingAnalyzer();
  final BatteryEstimator batteryEstimator = BatteryEstimator();
  final RemapEngine remapEngine = const RemapEngine();

  RemapProfile profile = RemapProfile.neutral;

  /// État brut (avant remap) — utile pour l'écran de remapping.
  PadState rawState = PadState.idle;

  /// Identifiant Android de la manette suivie (0 = aucune).
  int activeDeviceId = 0;

  /// Pont matériel (null tant qu'on n'a pas essayé).
  HardwareSource? hardware;

  /// Manettes réellement branchées (vide en simulation seule sur le web).
  List<PadDevice> hardwareDevices = const [];

  /// Message d'erreur du dernier essai matériel.
  String? hardwareError;

  /// Boutons « enfoncés » depuis l'écran (tactile), en attente de relâchement.
  /// Ils traversent exactement le même chemin qu'un appui matériel : remap,
  /// journal, analyseurs, notifications.
  final Map<PadButton, int> _injected = {};

  /// Simule un appui bref sur un bouton depuis l'interface.
  ///
  /// Le retour visuel est celui d'un vrai appui : l'état passe par
  /// [ingestRaw], donc la grille de boutons, le modèle 3D, le journal et les
  /// compteurs réagissent de la même façon.
  void tapButton(PadButton button, {Duration hold = const Duration(milliseconds: 170)}) {
    _injected[button] = (_injected[button] ?? 0) + 1;
    ingestRaw(rawState);
    Timer(hold, () {
      final left = (_injected[button] ?? 1) - 1;
      if (left <= 0) {
        _injected.remove(button);
      } else {
        _injected[button] = left;
      }
      ingestRaw(rawState);
    });
  }

  /// Vrai quand des données matérielles attendent un rafraîchissement UI.
  bool hardwareDirty = false;

  /// Diffusion vers PadLab Link (PC). Inactive par défaut.
  final LinkSender link = createLinkSender();

  bool analyzing = false;
  Duration analysisElapsed = Duration.zero;
  static const analysisDuration = Duration(seconds: 30);

  final List<Offset> trail = [];

  /// Journal des derniers changements de boutons (UI).
  final List<PadEvent> recentEvents = [];
  Timer? _timer;
  int _tick = 0;
  int _sequence = 0;
  double _batteryPercent = 78;

  // --- cycle de vie -------------------------------------------------------

  void _startSimulation() {
    device ??= const PadDevice(
      id: 1,
      // Nom volontairement explicite : ce n'est pas une vraie manette.
      name: 'DualSense · démonstration',
      vendorId: 1356,
      productId: 3302,
      connection: ConnectionGuess.bluetooth,
      controllerNumber: 1,
      capabilities: PadCapabilities(
        buttonBits: 0x3FFFFF,
        vibratorCount: 2,
        hasBattery: true,
        hasLight: true,
        hasMotion: true,
        hasTouchpad: true,
      ),
      profileId: 'dualsense',
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _simulateTick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void setSimulation(bool value) {
    setMode(value ? SourceMode.demo : SourceMode.real);
  }

  /// Change de source.
  ///
  /// L'état bascule **tout de suite** : l'interface ne doit jamais afficher
  /// « réel » une demi-seconde après qu'on a choisi « démo ». Seule la
  /// capture native, elle, se met en route de façon asynchrone.
  void setMode(SourceMode next) {
    if (_mode == next) return;
    _mode = next;
    switch (next) {
      case SourceMode.demo:
        _switchToDemo(note: null);
        _notify();
      case SourceMode.real:
        _switchToReal();
        _notify();
        unawaited(_startReal());
      case SourceMode.auto:
        unawaited(_applyMode());
    }
  }

  /// Démarrage de la capture réelle, avec le repli propre au mode explicite.
  Future<void> _startReal() async {
    await startHardware();
    if (hardwareError != null) {
      sourceNote = hardwareError;
      hardware?.watchDevices();
      _notify();
    }
  }

  /// Applique [_mode] : démarre ou coupe la capture réelle.
  ///
  /// En auto, la décision dépend de ce que le pont trouve : c'est ce qui
  /// manquait — la manette était détectée mais jamais écoutée.
  Future<void> _applyMode() async {
    switch (_mode) {
      case SourceMode.demo:
        _switchToDemo(note: null);
      case SourceMode.real:
        // Choix explicite : on ne retombe jamais en démonstration, même sans
        // manette. L'écran affiche alors « aucune manette ».
        _switchToReal();
        await startHardware();
        if (hardwareError != null) {
          sourceNote = hardwareError;
          // Même sans manette, on continue de guetter un branchement : en
          // mode « Manette », l'utilisateur attend qu'elle apparaisse seule.
          hardware?.watchDevices();
        }
      case SourceMode.auto:
        hardware ??= HardwareSource(this);
        final devices = await hardware!.listDevices();
        hardwareDevices = devices;
        if (devices.isEmpty) {
          _switchToDemo(
            note: 'Aucune manette détectée : entrées de démonstration.',
          );
          hardware!.watchDevices();
        } else {
          await startHardware();
          if (hardwareError != null && simulate) {
            _switchToDemo(note: hardwareError);
            hardware!.watchDevices();
          }
        }
    }
    _notify();
  }

  void _switchToReal() {
    _realSince ??= DateTime.now();
    _stopTimer();
    _injected.clear();
    // Les mesures de démonstration ne doivent pas se mélanger aux vraies :
    // on repart d'un historique vide, quitte à afficher « — » un moment.
    resetAnalysis();
    batteryEstimator.reset();
    battery = BatteryReading(
      at: DateTime.now(),
      status: BatteryStatus.unknown,
      percent: null,
    );
    simulate = false;
    sourceNote = null;
  }

  void _switchToDemo({String? note}) {
    _closeSession();
    unawaited(stopHardware());
    simulate = true;
    sourceNote = note;
    if (battery.percent == null) _seedBatteryHistory();
    if (_timer == null) _startSimulation();
  }

  // --- analyse ------------------------------------------------------------

  void toggleAnalysis() {
    if (analyzing) {
      analyzing = false;
    } else {
      leftStick.reset();
      rightStick.reset();
      leftTrigger.reset();
      rightTrigger.reset();
      polling.reset();
      trail.clear();
      analysisElapsed = Duration.zero;
      analyzing = true;
    }
    notifyListeners();
  }

  /// Injecte un jeu de mesures réalistes pour que l'écran d'analyse soit
  /// lisible dès l'ouverture (mode simulation). Le matériel réel remplace
  /// ces valeurs au fil des échantillons.
  void seedDemoAnalysis() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = math.Random(11);
    for (var i = 0; i < 900; i++) {
      final angle = i * 2 * math.pi / 900;
      // Ellipse légèrement irrégulière : circularité ~ 94-97 %.
      final wobble = 1 + math.sin(angle * 3 + 0.7) * 0.025 + rnd.nextDouble() * 0.006;
      leftStick.add(math.cos(angle) * 0.97 * wobble, math.sin(angle) * 0.97 * wobble, now + i * 4000);
      rightStick.add(math.cos(angle) * 0.95, math.sin(angle) * 0.95, now + i * 4000);
    }
    for (var i = 0; i < 120; i++) {
      leftTrigger.add((i / 119) * 0.99);
      rightTrigger.add((i / 119) * 0.955);
    }
    // Repos : petit drift réaliste de 0,8 %.
    for (var i = 0; i < 120; i++) {
      leftStick.add(0.006 + rnd.nextDouble() * 0.004, 0.004, now + (900 + i) * 4000);
      rightStick.add(0.003, -0.002 + rnd.nextDouble() * 0.003, now + (900 + i) * 4000);
    }
    for (var i = 0; i < 600; i++) {
      polling.addTimestamp(now + i * 4000 + rnd.nextInt(400));
    }
    notifyListeners();
  }

  void resetAnalysis() {
    leftStick.reset();
    rightStick.reset();
    leftTrigger.reset();
    rightTrigger.reset();
    polling.reset();
    trail.clear();
    analysisElapsed = Duration.zero;
    notifyListeners();
  }

  HealthReport buildHealthReport() {
    return const HealthScorer().score(
      leftStick: leftStick.compute(),
      rightStick: rightStick.compute(),
      leftTrigger: leftTrigger.compute(),
      rightTrigger: rightTrigger.compute(),
      polling: polling.compute(),
      buttonsTested: 18,
      buttonsFailed: 0,
      leftMotorOk: true,
      rightMotorOk: true,
    );
  }

  // --- remap --------------------------------------------------------------

  void updateProfile(RemapProfile next) {
    profile = next;
    notifyListeners();
  }

  void resetProfile() {
    profile = RemapProfile.neutral;
    notifyListeners();
  }

  // --- batterie -----------------------------------------------------------

  BatteryEstimate get batteryEstimate => batteryEstimator.estimate();

  BatteryHealth get batteryHealth {
    final estimate = batteryEstimator.estimate();
    final drain = estimate.drainPerHour;
    if (drain == null) return BatteryHealth.unknown;
    return const BatteryHealthEstimator().estimate(
      drainPerHour: drain,
      referenceHours: 8.5,
      confidence: estimate.confidence,
    );
  }

  /// Injecte 70 minutes d'historique pour démontrer l'estimation sans
  /// attendre une vraie session (mode simulation uniquement).
  void seedDemoBattery() {
    _seedBatteryHistory();
    notifyListeners();
  }

  void _seedBatteryHistory() {
    batteryEstimator.reset();
    final now = DateTime.now();
    for (var i = 0; i <= 14; i++) {
      batteryEstimator.add(BatteryReading(
        at: now.subtract(Duration(minutes: (14 - i) * 5)),
        status: BatteryStatus.discharging,
        percent: 88 - i * 1.0,
      ));
    }
    // La démonstration assume une batterie : elle doit être annoncée comme
    // simulée, jamais confondue avec une lecture native.
    _batteryPercent = 74;
    battery = BatteryReading(
      at: now,
      status: BatteryStatus.discharging,
      percent: _batteryPercent,
    );
  }

  // --- simulation ---------------------------------------------------------

  void _simulateTick() {
    _tick++;
    final t = _tick * 0.016;

    // Sticks : trajectoires lisses et crédibles.
    final lx = math.sin(t * 0.9) * 0.62 + math.sin(t * 2.3) * 0.08;
    final ly = math.cos(t * 0.7) * 0.48;
    final rx = math.sin(t * 1.3 + 1.2) * 0.35;
    final ry = math.cos(t * 1.7 + 0.4) * 0.55;

    // Gâchettes : rampes.
    final lt = (math.sin(t * 0.5) + 1) / 2 * 0.9;
    final rt = (math.sin(t * 0.8 + 2) + 1) / 2;

    final pressed = <PadButton>{};
    if (math.sin(t * 1.7) > 0.85) pressed.add(PadButton.a);
    if (math.sin(t * 2.1 + 1) > 0.9) pressed.add(PadButton.b);
    if (math.sin(t * 2.6 + 2) > 0.85) pressed.add(PadButton.x);
    if (math.sin(t * 3.1 + 3) > 0.9) pressed.add(PadButton.y);
    if (math.sin(t * 1.1) > 0.6) pressed.add(PadButton.dpadUp);
    if (math.sin(t * 0.9 + 1) > 0.7) pressed.add(PadButton.dpadRight);
    if (math.cos(t * 0.6) > 0.92) pressed.add(PadButton.r1);
    if (math.cos(t * 0.75 + 1) > 0.93) pressed.add(PadButton.l1);
    if (rt > 0.55) pressed.add(PadButton.r2);
    if (lt > 0.55) pressed.add(PadButton.l2);

    final timestampUs = DateTime.now().microsecondsSinceEpoch;
    _sequence++;

    rawState = PadState(
      pressed: pressed,
      axes: {
        PadAxis.leftX: lx,
        PadAxis.leftY: ly,
        PadAxis.rightX: rx,
        PadAxis.rightY: ry,
        PadAxis.leftTrigger: lt,
        PadAxis.rightTrigger: rt,
      },
      rawAxes: {
        PadAxis.leftX: (lx * 32767).roundToDouble(),
        PadAxis.leftY: (ly * 32767).roundToDouble(),
        PadAxis.rightX: (rx * 32767).roundToDouble(),
        PadAxis.rightY: (ry * 32767).roundToDouble(),
        PadAxis.leftTrigger: (lt * 255).roundToDouble(),
        PadAxis.rightTrigger: (rt * 255).roundToDouble(),
      },
      timestampUs: timestampUs,
      sequence: _sequence,
    );

    // Batterie : décharge réaliste (≈ 7 %/h) + imputation dans l'estimateur.
    _batteryPercent = math.max(0, _batteryPercent - 0.000031);
    if (_tick % 300 == 0) {
      setBattery(
        BatteryReading(
          at: DateTime.now(),
          status: BatteryStatus.discharging,
          percent: _batteryPercent,
        ),
      );
    }

    ingestRaw(rawState);
  }

  // --- ingestion (simulation ou matériel) ---------------------------------

  /// Ingère un état brut — issu de la simulation **ou** d'une manette réelle.
  /// Applique le remap, journalise les transitions, alimente les analyseurs
  /// et notifie l'UI.
  void ingestRaw(PadState raw, {bool notify = true}) {
    final timestampUs = raw.timestampUs;
    final previous = state.pressed;
    rawState = raw;
    final remapped = remapEngine.apply(raw, profile, nowUs: timestampUs);
    // Les appuis tactiles se superposent à l'état remappé, sans le remplacer.
    state = _injected.isEmpty
        ? remapped
        : remapped.copyWith(pressed: {...remapped.pressed, ..._injected.keys});

    for (final b in state.pressed.difference(previous)) {
      _logEvent(
        PadEvent(
          type: PadEventType.buttonDown,
          timestampUs: timestampUs,
          button: b,
          deviceId: activeDeviceId,
        ),
      );
    }
    for (final b in previous.difference(state.pressed)) {
      _logEvent(
        PadEvent(
          type: PadEventType.buttonUp,
          timestampUs: timestampUs,
          button: b,
          deviceId: activeDeviceId,
        ),
      );
    }

    // Analyses.
    leftStick.add(state.axis(PadAxis.leftX), state.axis(PadAxis.leftY), timestampUs);
    rightStick.add(state.axis(PadAxis.rightX), state.axis(PadAxis.rightY), timestampUs);
    leftTrigger.add(state.axis(PadAxis.leftTrigger));
    rightTrigger.add(state.axis(PadAxis.rightTrigger));
    polling.addTimestamp(timestampUs);

    if (analyzing) {
      analysisElapsed += const Duration(milliseconds: 16);
      if (analysisElapsed >= analysisDuration) analyzing = false;
    }

    // Traînée du stick gauche (limitée).
    trail.add(Offset(state.axis(PadAxis.leftX), state.axis(PadAxis.leftY)));
    if (trail.length > 160) trail.removeAt(0);

    // Diffusion PC : simple affectation, aucune allocation si inactif.
    link
      ..push(state)
      ..markDirty();

    if (notify) notifyListeners();
  }

  /// Force un rafraîchissement UI (utilisé par le mode matériel à 60 Hz).
  void pulse() {
    hardwareDirty = false;
    notifyListeners();
  }

  // --- matériel -----------------------------------------------------------

  /// Tente de brancher la capture native. Utilisable même en simulation pour
  /// savoir si une manette est présente.
  Future<void> startHardware() async {
    hardware ??= HardwareSource(this);
    final error = await hardware!.start();
    hardwareError = error;
    if (error == null && hardware!.hasDevice) {
      // La capture tourne : les entrées deviennent réelles. C'est la
      // bascule qui manquait à la 0.3.x.
      _stopTimer();
      _injected.clear();
      simulate = false;
      sourceNote = null;
    } else if (error != null) {
      hardwareError = error;
    }
    _notify();
  }

  Future<void> stopHardware() async {
    await hardware?.stop();
    _notify();
  }

  /// Vibration matérielle (deux moteurs). Sans effet en simulation.
  Future<bool> vibrate({
    double strong = 1.0,
    double weak = 1.0,
    int durationMs = 300,
  }) async {
    final source = hardware;
    if (source == null) return false;
    return source.vibrate(strong: strong, weak: weak, durationMs: durationMs);
  }

  Future<void> stopVibration() async {
    await hardware?.stopVibration();
  }

  /// Première décision : manette branchée ou non.
  ///
  /// C'est le point d'entrée appelé au démarrage. Il applique le mode choisi
  /// au lieu de rester en simulation.
  Future<void> detectHardware() async {
    lastAutoRefreshAt = DateTime.now();
    await _applyMode();
  }

  /// Relecture manuelle (bouton « rafraîchir ») : liste + batterie.
  Future<void> refreshNow() async {
    lastAutoRefreshAt = DateTime.now();
    await hardware?.refreshDevices();
    await hardware?.refreshBattery();
    _notify();
  }

  /// Réaction à un branchement/débranchement, appelée par la source native.
  ///
  /// En mode auto uniquement : un changement de matériel ne doit pas écraser
  /// un choix explicite de l'utilisateur.
  void onHardwareDevicesChanged(
    List<PadDevice> devices, {
    bool hardwareLive = false,
  }) {
    hardwareDevices = devices;
    lastAutoRefreshAt ??= DateTime.now();
    if (_mode != SourceMode.auto) {
      if (devices.isEmpty && isReal) {
        sourceNote = 'Manette débranchée.';
      }
      _notify();
      return;
    }
    if (devices.isEmpty && isReal) {
      _switchToDemo(note: 'Manette débranchée : retour à la démonstration.');
      _notify();
    } else if (devices.isNotEmpty && simulate) {
      if (hardwareLive) {
        // La capture est déjà en train de démarrer : inutile de la relancer.
        _switchToReal();
        sourceNote = 'Manette détectée : entrées réelles.';
        _notify();
      } else {
        _switchToReal();
        unawaited(startHardware());
        sourceNote = 'Manette détectée : entrées réelles.';
        _notify();
      }
    } else {
      _notify();
    }
  }

  /// Clôt la session réelle en cours, si elle a duré assez longtemps pour
  /// valoir la peine d'être notée.
  void _closeSession() {
    final start = _realSince;
    _realSince = null;
    if (start == null || device == null) return;
    final duration = DateTime.now().difference(start);
    if (duration.inSeconds < 3) return;
    sessions.insert(
      0,
      SessionRecord(
        name: device!.name,
        startedAt: start,
        duration: duration,
        score: buildHealthReport().score,
      ),
    );
    if (sessions.length > 12) sessions.removeLast();
  }

  /// Met à jour la manette courante (branchement/débranchement).
  void setDevice(PadDevice? next) {
    device = next;
    activeDeviceId = next?.id ?? 0;
    _notify();
  }

  /// Dernière raison expliquant l'absence de niveau de batterie.
  String? batteryUnavailableReason;

  /// Enregistre qu'aucune valeur n'est disponible, avec sa raison.
  void setBatteryUnavailable(String reason) {
    if (_disposed) return;
    batteryUnavailableReason = reason;
    if (battery.percent != null) {
      // On garde la dernière valeur connue plutôt que de l'effacer : une
      // lecture ratée ne doit pas faire disparaître un niveau déjà lu.
      _notify();
      return;
    }
    battery = BatteryReading(
      at: DateTime.now(),
      status: BatteryStatus.unknown,
      percent: null,
    );
    _notify();
  }

  /// Met à jour la batterie (lecture native ou simulation continue).
  void setBattery(BatteryReading reading) {
    if (_disposed) return;
    batteryUnavailableReason = null;
    battery = reading;
    batteryEstimator.add(reading);
    _notify();
  }

  void _logEvent(PadEvent event) {
    recentEvents.insert(0, event);
    if (recentEvents.length > 8) recentEvents.removeLast();
  }

  @override
  void dispose() {
    _closeSession();
    _disposed = true;
    _injected.clear();
    _stopTimer();
    link.stop();
    // La source matérielle garde des minuteurs (rendu 60 Hz, batterie) :
    // il faut les arrêter, sinon l'application ne se libère jamais.
    unawaited(hardware?.dispose());
    hardware = null;
    super.dispose();
  }
}
