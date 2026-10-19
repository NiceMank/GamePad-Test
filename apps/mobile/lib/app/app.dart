import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pad_ui/pad_ui.dart';

import '../features/analysis/analysis_screen.dart';
import '../features/battery/battery_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tester/tester_screen.dart';
import '../session/pad_session.dart';
import 'scope.dart';

class PadLabApp extends StatefulWidget {
  const PadLabApp({super.key});

  @override
  State<PadLabApp> createState() => _PadLabAppState();
}

class _PadLabAppState extends State<PadLabApp> {
  final PadSession _session = PadSession();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    // Détection silencieuse : l'UI reste en simulation mais sait si du
    // matériel est présent (badge Réglages, accueil).
    unawaited(_session.detectHardware());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PadScope doit envelopper MaterialApp : sinon les écrans poussés par le
    // Navigator (Remapping, PadLab Link) ne voient pas la session.
    return PadScope(
      session: _session,
      child: MaterialApp(
        title: 'PadLab',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: PadTheme.build(Brightness.light),
        darkTheme: PadTheme.build(Brightness.dark),
        home: HomeShell(
          themeMode: _themeMode,
          onThemeMode: (mode) => setState(() => _themeMode = mode),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themeMode, required this.onThemeMode});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = PadScope.of(context);

    final screens = [
      HomeScreen(onNavigate: _go),
      const TesterScreen(),
      const AnalysisScreen(),
      const BatteryScreen(),
      SettingsScreen(themeMode: widget.themeMode, onThemeMode: widget.onThemeMode),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: screens),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF070C15) : Colors.white,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: _index == 0, onTap: () => _go(0)),
                _NavItem(icon: Icons.sports_esports_rounded, label: 'Test', selected: _index == 1, onTap: () => _go(1)),
                _NavItem(icon: Icons.insights_rounded, label: 'Analyse', selected: _index == 2, onTap: () => _go(2)),
                _NavItem(icon: Icons.battery_charging_full_rounded, label: 'Batterie', selected: _index == 3, onTap: () => _go(3)),
                _NavItem(icon: Icons.settings_rounded, label: 'Réglages', selected: _index == 4, onTap: () => _go(4)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: session.analyzing
          ? null
          : null,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.cyan : (c.isDark ? const Color(0xFF5D6D85) : const Color(0xFF8798AD));
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
