import 'package:flutter/widgets.dart';

import '../session/pad_session.dart';

/// Rend la session accessible à tout l'arbre et rebuild à chaque tick.
class PadScope extends InheritedNotifier<PadSession> {
  const PadScope({super.key, required PadSession session, required super.child})
    : super(notifier: session);

  static PadSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PadScope>();
    assert(scope != null, 'PadScope manquant');
    return scope!.notifier!;
  }
}
