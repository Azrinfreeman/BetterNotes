import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutoStart {
  static const _channel = MethodChannel('betternotes/windows');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<bool> isEnabled() async =>
      await _channel.invokeMethod<bool>('getAutoStart') ?? false;

  static Future<void> setEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setAutoStart', enabled);
}
