import 'package:flutter/foundation.dart';

/// Opt-in timings contain durations and counts only, never notebook content.
class StartupTiming {
  static bool enabled = const bool.fromEnvironment('STARTUP_TIMING');
  static final _clock = Stopwatch()..start();
  static final _marks = <String, int>{};
  static final _work = <String, int>{};
  static final _counts = <String, int>{};

  static void mark(String stage) {
    if (enabled) _marks[stage] = _clock.elapsedMilliseconds;
  }

  static void markOnce(String stage) {
    if (enabled) _marks.putIfAbsent(stage, () => _clock.elapsedMilliseconds);
  }

  static Future<T> measure<T>(String stage, Future<T> Function() action) async {
    if (!enabled) return action();
    final clock = Stopwatch()..start();
    try {
      return await action();
    } finally {
      _work.update(
        stage,
        (value) => value + clock.elapsedMilliseconds,
        ifAbsent: () => clock.elapsedMilliseconds,
      );
      _counts.update(stage, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  static Map<String, Object> get snapshot => {
    'marksMs': Map.of(_marks),
    'workMs': Map.of(_work),
    'counts': Map.of(_counts),
  };

  static void report() {
    if (enabled) debugPrint('Startup timing: $snapshot');
  }
}
