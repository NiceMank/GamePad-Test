import 'package:flutter/material.dart';
import 'package:pad_ui/pad_ui.dart';

import 'src/app.dart';

void main() => runApp(const PadLinkApp());

/// PadLab Link — bureau Windows/Linux.
class PadLinkApp extends StatelessWidget {
  const PadLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadLab Link',
      debugShowCheckedModeBanner: false,
      theme: PadTheme.build(Brightness.dark),
      home: const LinkApp(),
    );
  }
}
