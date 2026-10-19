import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pad_core/pad_core.dart';
import 'package:test/test.dart';

void main() {
  group('StickAnalyzer', () {
    test('détecte le drift au repos', () {
      final analyzer = StickAnalyzer();
      for (var i = 0; i < 200; i++) {
        analyzer.add(0.03, 0.02, i * 4000);
      }
      final m = analyzer.compute();
      expect(m.samples, 200);
      expect(m.driftPercent, closeTo(3.6, 0.6));
      expect(m.verdict, contains('Drift'));
    });

    test('cercle parfait -> circularité ~100 %', () {
      final analyzer = StickAnalyzer();
      for (var i = 0; i < 720; i++) {
        final a = i * 2 * math.pi / 720;
        analyzer.add(math.cos(a) * 0.98, math.sin(a) * 0.98, i * 4000);
      }
      final m = analyzer.compute();
      expect(m.circularityPercent, greaterThan(99));
      expect(m.coveragePercent, greaterThan(70));
    });

    test('zone morte détectée sur un stick qui saute', () {
      final analyzer = StickAnalyzer();
      for (var i = 0; i < 100; i++) {
        analyzer.add(0.18, 0.0, i * 4000); // jamais sous 0.12 -> pas au repos
      }
      for (var i = 0; i < 100; i++) {
        analyzer.add(0.30, 0.0, i * 4000);
      }
      final m = analyzer.compute();
      expect(m.deadzonePercent, closeTo(18, 1.5));
    });
  });

  group('TriggerAnalyzer', () {
    test('course linéaire complète', () {
      final a = TriggerAnalyzer();
      for (var i = 0; i <= 100; i++) {
        a.add(i / 100);
      }
      final m = a.compute();
      expect(m.travelPercent, closeTo(100, 0.01));
      expect(m.linearityPercent, greaterThan(99));
      expect(m.verdict, 'Gâchette saine');
    });

    test('course incomplète à 96 %', () {
      final a = TriggerAnalyzer();
      for (var i = 0; i <= 100; i++) {
        a.add(i / 100 * 0.96);
      }
      final m = a.compute();
      expect(m.travelPercent, closeTo(96, 0.2));
      expect(m.linearityPercent, greaterThan(99));
      expect(m.verdict, contains('Course incomplète'));
    });
  });

  group('PollingAnalyzer', () {
    test('1000 Hz sans jitter', () {
      final p = PollingAnalyzer();
      for (var i = 0; i < 500; i++) {
        p.addTimestamp(i * 1000);
      }
      final m = p.compute();
      expect(m.hz, closeTo(1000, 1));
      expect(m.jitterMs, closeTo(0, 0.001));
      expect(m.quality, 'Stable');
    });

    test('détecte les micro-coupures', () {
      final p = PollingAnalyzer();
      var t = 0;
      for (var i = 0; i < 100; i++) {
        t += (i % 20 == 0) ? 40000 : 4000;
        p.addTimestamp(t);
      }
      final m = p.compute();
      expect(m.stalls, greaterThan(0));
    });
  });

  group('BatteryEstimator', () {
    test('décharge 80 % -> 70 % en 20 min => ~2 h restantes', () {
      final e = BatteryEstimator();
      final start = DateTime(2026, 10, 19, 10);
      for (var i = 0; i <= 10; i++) {
        e.add(BatteryReading(
          at: start.add(Duration(minutes: i * 2)),
          status: BatteryStatus.discharging,
          percent: 80 - i * 1.0,
        ));
      }
      final estimate = e.estimate();
      expect(estimate.drainPerHour, closeTo(30, 2));
      expect(estimate.remaining!.inMinutes, closeTo(140, 15));
      expect(estimate.confidence, greaterThan(0.4));
      expect(estimate.isReliable, isTrue);
    });

    test('charge 50 % -> 60 % en 30 min => ~2 h avant 100 %', () {
      final e = BatteryEstimator();
      final start = DateTime(2026, 10, 19, 10);
      for (var i = 0; i <= 6; i++) {
        e.add(BatteryReading(
          at: start.add(Duration(minutes: i * 5)),
          status: BatteryStatus.charging,
          percent: 50 + i * (10 / 6),
        ));
      }
      final estimate = e.estimate();
      expect(estimate.toFull, isNotNull);
      expect(estimate.toFull!.inMinutes, closeTo(120, 20));
    });

    test('pas d\'estimation sans données suffisantes', () {
      final e = BatteryEstimator();
      e.add(BatteryReading(
        at: DateTime(2026, 10, 19, 10),
        status: BatteryStatus.discharging,
        percent: 80,
      ));
      final estimate = e.estimate();
      expect(estimate.remaining, isNull);
      expect(estimate.isReliable, isFalse);
      expect(estimate.reason, isNotNull);
    });

    test('santé estimée : endurance 4 h vs référence 8 h => ~50 %', () {
      const e = BatteryHealthEstimator();
      final health = e.estimate(
        drainPerHour: 25,
        referenceHours: 8,
        confidence: 0.8,
      );
      expect(health.score, closeTo(50, 1));
      expect(health.grade, 'D');
    });
  });

  group('HealthScorer', () {
    test('manette saine => score élevé et aucune alerte critique', () {
      final left = StickAnalyzer();
      final right = StickAnalyzer();
      for (var i = 0; i < 720; i++) {
        final a = i * 2 * math.pi / 720;
        left.add(math.cos(a) * 0.97, math.sin(a) * 0.97, i * 4000);
        right.add(math.cos(a) * 0.97, math.sin(a) * 0.97, i * 4000);
      }
      final lt = TriggerAnalyzer();
      final rt = TriggerAnalyzer();
      for (var i = 0; i <= 100; i++) {
        lt.add(i / 100);
        rt.add(i / 100 * 0.98);
      }
      final polling = PollingAnalyzer();
      for (var i = 0; i < 300; i++) {
        polling.addTimestamp(i * 4000);
      }
      final report = const HealthScorer().score(
        leftStick: left.compute(),
        rightStick: right.compute(),
        leftTrigger: lt.compute(),
        rightTrigger: rt.compute(),
        polling: polling.compute(),
        buttonsTested: 18,
        buttonsFailed: 0,
        leftMotorOk: true,
        rightMotorOk: true,
      );
      expect(report.score, greaterThanOrEqualTo(85));
      expect(report.grade, anyOf('A', 'B'));
      expect(
        report.issues.where((i) => i.severity == IssueSeverity.critical),
        isEmpty,
      );
    });

    test('drift énorme => score dégradé et alerte critique', () {
      final bad = StickAnalyzer();
      for (var i = 0; i < 300; i++) {
        bad.add(0.20, 0.05, i * 4000);
      }
      final report = const HealthScorer().score(
        leftStick: bad.compute(),
        rightStick: StickMetrics.empty,
        leftTrigger: TriggerMetrics.empty,
        rightTrigger: TriggerMetrics.empty,
      );
      expect(report.score, lessThan(60));
      expect(
        report.issues.any((i) =>
            i.severity == IssueSeverity.critical && i.title.contains('Drift')),
        isTrue,
      );
    });
  });

  group('RemapEngine', () {
    const engine = RemapEngine();

    test('remappe un bouton', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'Swap',
        buttonMap: {PadButton.a: PadButton.b},
      );
      final out = engine.apply(
        const PadState(pressed: {PadButton.a, PadButton.x}),
        profile,
      );
      expect(out.pressed, {PadButton.b, PadButton.x});
    });

    test('désactive un bouton', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'No guide',
        disabledButtons: {PadButton.guide},
      );
      final out = engine.apply(
        const PadState(pressed: {PadButton.guide, PadButton.a}),
        profile,
      );
      expect(out.pressed, {PadButton.a});
    });

    test('zone morte radiale', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'DZ',
        leftStick: AxisSettings(deadzone: 0.2),
      );
      final out = engine.apply(
        const PadState(axes: {PadAxis.leftX: 0.12, PadAxis.leftY: 0.05}),
        profile,
      );
      expect(out.axis(PadAxis.leftX), 0);
      expect(out.axis(PadAxis.leftY), 0);
    });

    test('inversion d\'axe', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'Inv',
        leftStick: AxisSettings(deadzone: 0, invertY: true),
      );
      final out = engine.apply(
        const PadState(axes: {PadAxis.leftY: 0.8}),
        profile,
      );
      expect(out.axis(PadAxis.leftY), closeTo(-0.8, 0.001));
    });

    test('stick -> D-pad', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'S2D',
        stickToDpad: true,
        leftStick: AxisSettings(deadzone: 0),
      );
      final out = engine.apply(
        const PadState(axes: {PadAxis.leftX: 0.9, PadAxis.leftY: 0.0}),
        profile,
      );
      expect(out.pressed.contains(PadButton.dpadRight), isTrue);
      expect(out.pressed.contains(PadButton.dpadLeft), isFalse);
    });

    test('gâchette -> bouton L2 selon le seuil', () {
      const profile = RemapProfile(
        id: 'p',
        name: 'Trig',
        leftTrigger: TriggerSettings(threshold: 0.5, asButton: true),
      );
      final low = engine.apply(
        const PadState(axes: {PadAxis.leftTrigger: 0.3}),
        profile,
      );
      final high = engine.apply(
        const PadState(axes: {PadAxis.leftTrigger: 0.8}),
        profile,
      );
      expect(low.pressed.contains(PadButton.l2), isFalse);
      expect(high.pressed.contains(PadButton.l2), isTrue);
    });

    test('profil neutre = identité', () {
      const state = PadState(pressed: {PadButton.a});
      expect(engine.apply(state, RemapProfile.neutral), same(state));
    });

    test('sérialisation JSON aller-retour', () {
      const profile = RemapProfile(
        id: 'dualsense',
        name: 'DualSense FPS',
        deviceKey: '1356:3302:DualSense',
        buttonMap: {PadButton.a: PadButton.x},
        leftStick: AxisSettings(deadzone: 0.12, curve: AxisCurve.precision),
        stickToDpad: true,
        systemWide: true,
      );
      final restored = RemapProfile.fromJson(profile.toJson());
      expect(restored.name, profile.name);
      expect(restored.buttonMap, profile.buttonMap);
      expect(restored.leftStick.deadzone, 0.12);
      expect(restored.leftStick.curve, AxisCurve.precision);
      expect(restored.stickToDpad, isTrue);
      expect(restored.systemWide, isTrue);
    });
  });

  group('LinkProtocol', () {
    test('paquet d\'état : taille et aller-retour', () {
      const state = PadState(
        pressed: {PadButton.a, PadButton.r2, PadButton.dpadUp},
        axes: {
          PadAxis.leftX: -0.5,
          PadAxis.leftY: 0.25,
          PadAxis.rightX: 1.0,
          PadAxis.rightY: -1.0,
          PadAxis.leftTrigger: 0.0,
          PadAxis.rightTrigger: 0.87,
        },
        timestampUs: 123456789,
        sequence: 42,
      );
      final packet = LinkStatePacket.fromPadState(
        state,
        token: 0xBEEF,
        sequence: 42,
        batteryPercent: 78,
        batteryStatus: BatteryStatus.discharging,
      );
      final bytes = packet.encode();
      expect(bytes.length, LinkProtocol.statePacketSize);

      final decoded = LinkStatePacket.decode(bytes);
      expect(decoded.token, 0xBEEF);
      expect(decoded.sequence, 42);
      expect(decoded.timestampUs, 123456789);
      expect(decoded.batteryPercent, 78);
      expect(decoded.batteryStatus, BatteryStatus.discharging);

      final round = decoded.toPadState();
      expect(round.pressed, state.pressed);
      expect(round.axis(PadAxis.leftX), closeTo(-0.5, 0.001));
      expect(round.axis(PadAxis.rightY), closeTo(-1.0, 0.001));
      expect(round.axis(PadAxis.rightTrigger), closeTo(0.87, 0.001));
    });

    test('magic invalide rejeté', () {
      final bytes = Uint8List(LinkProtocol.statePacketSize);
      expect(() => LinkStatePacket.decode(bytes), throwsFormatException);
    });

    test('ping aller-retour', () {
      const ping = LinkPingPacket(token: 7, clientTimeUs: 999);
      final decoded = LinkPingPacket.decode(ping.encode());
      expect(decoded.token, 7);
      expect(decoded.clientTimeUs, 999);
      expect(decoded.type, LinkProtocol.typePing);
    });
  });
}
