// Run with: dart test -p chrome test/backup_browser_test.dart
// Plain package:test avoids the Flutter web test host, which cannot start here.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:better_notes/data/backup_files_web.dart' as files;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'browser upload returns the selected bytes and removes the input',
    () async {
      final bytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
      final upload = files.pickBackup();
      final input = web.document.querySelector(
        'input[type=file]',
      ) as web.HTMLInputElement;
      final transfer = web.DataTransfer();
      transfer.items.add(web.File([bytes.toJS].toJS, 'backup.zip'));
      input.files = transfer.files;
      input.dispatchEvent(web.Event('change'));
      expect(await upload, bytes);
      expect(web.document.querySelector('input[type=file]'), isNull);
    },
  );

  test('browser picker cancellation returns null', () async {
    final cancelled = files.pickBackup();
    (web.document.querySelector('input[type=file]') as web.HTMLInputElement)
        .dispatchEvent(web.Event('cancel'));
    expect(await cancelled, isNull);
    expect(web.document.querySelector('input[type=file]'), isNull);
  });

  test('an empty selection is treated as cancellation', () async {
    final upload = files.pickBackup();
    (web.document.querySelector('input[type=file]') as web.HTMLInputElement)
        .dispatchEvent(web.Event('change'));
    expect(await upload, isNull);
  });

  test('saving a backup triggers a download link and cleans it up', () async {
    final saved = await files.saveBackupFile(Uint8List(4), 'notes.zip');
    expect(saved, isTrue);
    expect(web.document.querySelector('a[download]'), isNull);
  });
}
