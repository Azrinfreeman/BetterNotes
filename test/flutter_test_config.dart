import 'dart:async';

import 'package:better_notes/data/clipboard_image.dart';

/// Runs before every test file: image shrinking happens inline in tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  runImageWorkInline = true;
  await testMain();
}
