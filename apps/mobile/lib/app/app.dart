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

class _PadLabAppState extends State<PadLabApp> with WidgetsBindingObserver {
  final PadSession _session = PadSession();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Première décision : manette branchée → entrées réelles, sinon
    // démonstration annoncée comme telle.
    unawaited(_session.detectHardware());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Une manette branchée pendant que l'application était en arrière-plan
    // ne déclenche pas toujours l'écouteur natif : on re-sonde au retour.
    if (state == AppLifecycleState.resumed) {
      unawaited(_session.detectHardware());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final screens = [
      HomeScreen(onNavigate: _go),
      const TesterScreen(),
      const AnalysisScreen(),
      const BatteryScreen(),
      SettingsScreen(themeMode: widget.themeMode, onThemeMode: widget.onThemeMode),
    ];

    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 76),
          child: IndexedStack(index: _index, children: screens),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNav(index: _index, onTap: _go),
    );
  }
}



/// Barre de navigation flottante : une pilule sombre, pas de bandeau plein.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.sports_esports_rounded, 'Test'),
    (Icons.insights_rounded, 'Analyse'),
    (Icons.battery_5_bar_rounded, 'Batterie'),
    (Icons.settings_rounded, 'Réglages'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xFF17191D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: i == index ? c.text.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            _items[i].$1,
                            size: 19,
                            color: i == index ? c.text : c.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                            color: i == index ? c.text : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
