import 'package:flutter/services.dart';

/// Windows modifier flags for RegisterHotKey.
const _alt = 1, _control = 2, _shift = 4, _win = 8;

class QuickCapturePreset {
  const QuickCapturePreset(this.label, this.modifiers, this.key);
  final String label;
  final int modifiers;
  final int key;
}

/// Shortcuts offered in Settings. 'off' is the default.
const quickCapturePresets = <String, QuickCapturePreset>{
  'off': QuickCapturePreset('Off', 0, 0),
  'ctrl_alt_n': QuickCapturePreset('Ctrl+Alt+N', _control | _alt, 0x4E),
  'ctrl_alt_b': QuickCapturePreset('Ctrl+Alt+B', _control | _alt, 0x42),
  'ctrl_shift_alt_n': QuickCapturePreset(
    'Ctrl+Shift+Alt+N',
    _control | _shift | _alt,
    0x4E,
  ),
  'win_shift_n': QuickCapturePreset('Win+Shift+N', _win | _shift, 0x4E),
};

/// Native tray icon and global hotkey, implemented in the Windows runner.
class DesktopIntegration {
  static const _channel = MethodChannel('betternotes/windows');

  /// Shows a tray balloon (a Windows notification). Returns false when
  /// Windows refused it.
  static Future<bool> showBalloon(String title, String text) async =>
      await _channel.invokeMethod<bool>('showBalloon', [title, text]) ?? false;

  static Future<void> setTray(bool visible) =>
      _channel.invokeMethod<void>('setTray', visible);

  /// Throws a [PlatformException] with code `hotkey_in_use` when another app
  /// already owns the shortcut.
  static Future<void> setQuickCapture(String id) {
    final preset = quickCapturePresets[id] ?? quickCapturePresets['off']!;
    return _channel.invokeMethod<void>('setQuickCapture', [
      preset.key != 0,
      preset.modifiers,
      preset.key,
    ]);
  }
}
