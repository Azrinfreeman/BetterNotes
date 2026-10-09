import 'dart:convert';
import 'dart:typed_data';

import 'package:better_notes/data/note.dart';
import 'package:better_notes/data/pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PDF export renders formatted text, lists, images and non-Latin text',
    () async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lQAAAABJRU5ErkJggg==',
      );
      final note = Note.fresh(guestOwner).copyWith(
        title: 'Report ✓',
        tags: ['work'],
        images: ['i1'],
        delta: [
          {'insert': 'Heading'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {
            'insert': 'bold 中文',
            'attributes': {'bold': true, 'italic': true},
          },
          {'insert': '\n'},
          {'insert': 'task'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': 'quoted'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
          {
            'insert': {'image': 'i1'},
          },
          {'insert': '\n'},
        ],
      );
      final file = await exportPdf(
        note,
        (_, id) async => id == 'i1' ? Uint8List.fromList(png) : null,
      );
      expect(file.name, 'Report ✓.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
      expect(file.bytes.length, greaterThan(1000));
    },
  );

  test('an empty note and a missing image still produce a PDF', () async {
    final file = await exportPdf(
      Note.fresh(guestOwner).copyWith(images: ['gone']),
      (_, _) async => null,
    );
    expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
  });
}
