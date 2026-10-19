import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:pad_core/pad_core.dart';

import 'hardware_source.dart';
import 'link_sender.dart';

/// Session de test : source d'état (matériel ou simulation), analyses et
/// batterie. L'UI n'écoute que ce notifier.
class PadSession extends ChangeNotifier {
  PadSession({this.simulate = true}) {
    _seedBatteryHistory();
    if (simulate) {
      _startSimulation();
      seedDemoAnalysis();
    }
  }

  bool simulate;

  PadDevice? device;
  PadState state = PadState.idle;
  BatteryReading battery = BatteryReading(
    at: DateTime.now(),
    status: BatteryStatus.discharging,
    percent: 78,
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
  int activeDeviceId = 1;

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
      name: 'DualSense Wireless',
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
    if (simulate == value) return;
    simulate = value;
    if (value) {
      unawaited(stopHardware());
      _startSimulation();
    } else {
      _stopTimer();
      unawaited(startHardware());
    }
    notifyListeners();
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
    _seedBatteryHistory(force: true);
    notifyListeners();
  }

  void _seedBatteryHistory({bool force = false}) {
    batteryEstimator.reset();
    final now = DateTime.now();
    for (var i = 0; i <= 14; i++) {
      batteryEstimator.add(BatteryReading(
        at: now.subtract(Duration(minutes: (14 - i) * 5)),
        status: BatteryStatus.discharging,
        percent: 88 - i * 1.0,
      ));
    }
    if (force) {
      _batteryPercent = 74;
      battery = BatteryReading(
        at: now,
        status: BatteryStatus.discharging,
        percent: _batteryPercent,
      );
    } else {
      batteryEstimator.add(battery);
    }
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
    hardwareError = await hardware!.start();
    notifyListeners();
  }

  Future<void> stopHardware() async {
    await hardware?.stop();
    notifyListeners();
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

  /// Détection silencieuse au démarrage (sans passer en mode matériel).
  Future<void> detectHardware() async {
    hardware ??= HardwareSource(this);
    final devices = await hardware!.listDevices();
    hardwareDevices = devices;
    if (devices.isNotEmpty && simulate) {
      // On garde la simulation, mais on connaît la manette présente.
      device ??= devices.first;
    }
    notifyListeners();
  }

  /// Met à jour la manette courante (branchement/débranchement).
  void setDevice(PadDevice? next) {
    device = next;
    activeDeviceId = next?.id ?? 0;
    notifyListeners();
  }

  /// Met à jour la batterie (lecture native ou simulation continue).
  void setBattery(BatteryReading reading) {
    battery = reading;
    batteryEstimator.add(reading);
    notifyListeners();
  }

  void _logEvent(PadEvent event) {
    recentEvents.insert(0, event);
    if (recentEvents.length > 8) recentEvents.removeLast();
  }

  @override
  void dispose() {
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
