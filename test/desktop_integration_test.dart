import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/desktop/tray.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tray and shortcut settings persist and roll back on failure', () async {
    final db = await databaseFactoryMemory.openDatabase('desktop-integration');
    final controller = NotesController(LocalStore.fromDatabase(db), null);
    await controller.load();
    expect(controller.keepInTray, isFalse);
    expect(controller.quickCaptureKey, 'off');

    var trayCalls = 0;
    controller.applyTray = () async => trayCalls++;
    await controller.setKeepInTray(true);
    expect(controller.keepInTray, isTrue);
    expect(trayCalls, 1);
    controller.applyTray = () async => throw StateError('no tray');
    await expectLater(controller.setKeepInTray(false), throwsStateError);
    expect(controller.keepInTray, isTrue);

    controller.applyQuickCapture = () async {};
    await controller.setQuickCaptureKey('ctrl_alt_n');
    controller.applyQuickCapture = () async =>
        throw PlatformException(code: 'hotkey_in_use');
    await expectLater(
      controller.setQuickCaptureKey('ctrl_alt_b'),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.quickCaptureKey, 'ctrl_alt_n');
    controller.dispose();

    final reopened = NotesController(LocalStore.fromDatabase(db), null);
    await reopened.load();
    expect(reopened.keepInTray, isTrue);
    expect(reopened.quickCaptureKey, 'ctrl_alt_n');
    reopened.dispose();
    await db.close();
  });

  test('every shortcut preset has a modifier and a key', () {
    for (final entry in quickCapturePresets.entries) {
      if (entry.key == 'off') continue;
      expect(entry.value.modifiers, isNonZero, reason: entry.key);
      expect(entry.value.key, inInclusiveRange(0x41, 0x5A), reason: entry.key);
    }
    expect(quickCapturePresets.length, greaterThan(2));
  });
}
