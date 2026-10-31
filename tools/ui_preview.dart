// flutter run -d windows -t tools/ui_preview.dart --dart-entrypoint-args=--ui-review
// Isolated notebook; never opens the user's library.
import 'package:better_notes/main.dart' as app;

Future<void> main() => app.main(['--ui-review']);
