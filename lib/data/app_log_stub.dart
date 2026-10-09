/// Browser builds keep no log file.
class AppLog {
  static String? get path => null;
  static Future<void> init() async {}
  static void write(
    String level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {}
  static Future<List<String>> tail([int lines = 80]) async => const [];
}
