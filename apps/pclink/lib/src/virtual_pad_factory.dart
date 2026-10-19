import 'dart:io';

import 'backends/linux_uinput.dart';
import 'backends/null_pad.dart';
import 'backends/windows_vigem.dart';
import 'virtual_pad.dart';

/// Crée le backend adapté à la plateforme, avec repli explicite.
Future<VirtualPad> createVirtualPad({bool simulate = false}) async {
  if (simulate) {
    final pad = NullPad(reason: 'Sortie virtuelle désactivée (mode démo).');
    await pad.start();
    return pad;
  }

  if (Platform.isWindows) {
    final pad = WindowsViGEmPad();
    if (await pad.start()) return pad;
    final fallback = NullPad(reason: pad.detail);
    await fallback.start();
    return fallback;
  }

  if (Platform.isLinux) {
    final pad = LinuxUinputPad();
    if (await pad.start()) return pad;
    final fallback = NullPad(reason: pad.detail);
    await fallback.start();
    return fallback;
  }

  final fallback = NullPad(
    reason: 'Plateforme ${Platform.operatingSystem} non supportée pour la sortie virtuelle.',
  );
  await fallback.start();
  return fallback;
}
