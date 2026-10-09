import 'package:better_notes/ui/startup_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers retry and a confirmed non-destructive reset', (
    tester,
  ) async {
    var retries = 0;
    var resets = 0;
    await tester.pumpWidget(
      StartupErrorApp(
        error: const FormatException('bad database'),
        onRetry: () async => retries++,
        onReset: () async {
          resets++;
          return 'moved';
        },
      ),
    );
    expect(find.textContaining('bad database'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);

    await tester.tap(find.text('Start empty (keep a copy)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(resets, 0);

    await tester.tap(find.text('Start empty (keep a copy)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start empty'));
    await tester.pumpAndSettle();
    expect(resets, 1);
    expect(retries, 2);
  });

  testWidgets('shows a failed retry and hides reset when unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupErrorApp(
        error: 'boom',
        canReset: false,
        onRetry: () async => throw StateError('still broken'),
        onReset: () async => null,
      ),
    );
    expect(find.text('Start empty (keep a copy)'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('still broken'), findsOneWidget);
  });
}
