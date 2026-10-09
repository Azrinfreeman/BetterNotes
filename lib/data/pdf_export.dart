import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'markdown_export.dart';
import 'note.dart';

/// The built-in PDF fonts cover Latin-1 only; other characters become '?'.
String _latin1(String text) => String.fromCharCodes(
  text.runes.map((rune) => rune < 256 && rune != 0xFFFC ? rune : 0x3F),
);

Uint8List? _pdfImageBytes(Uint8List bytes) {
  final jpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final png = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
  if (jpeg || png) return bytes;
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : Uint8List.fromList(img.encodePng(decoded));
}

/// Renders one note as a printable A4 PDF (text formatting, lists, checklists
/// and images; ink drawings are not included).
Future<ExportFile> exportPdf(Note note, ImageLoader loadImage) async {
  final images = <String, pw.MemoryImage>{};
  for (final id in {...note.images, ...inlineImageIds(note.delta)}) {
    final raw = await loadImage(note.id, id);
    final bytes = raw == null ? null : _pdfImageBytes(raw);
    if (bytes != null) {
      try {
        images[id] = pw.MemoryImage(bytes);
      } catch (_) {
        // Skip images the PDF writer cannot embed.
      }
    }
  }

  pw.TextStyle styleFor(Map<String, dynamic> a, double size) => pw.TextStyle(
    fontSize: size,
    font: a['bold'] == true && a['italic'] == true
        ? pw.Font.helveticaBoldOblique()
        : a['bold'] == true
        ? pw.Font.helveticaBold()
        : a['italic'] == true
        ? pw.Font.helveticaOblique()
        : a['code'] == true
        ? pw.Font.courier()
        : pw.Font.helvetica(),
    decoration:
        [
          if (a['underline'] == true) pw.TextDecoration.underline,
          if (a['strike'] == true) pw.TextDecoration.lineThrough,
        ].fold<pw.TextDecoration?>(
          null,
          (all, one) =>
              all == null ? one : pw.TextDecoration.combine([all, one]),
        ),
    color: a['link'] is String ? PdfColors.blue800 : PdfColors.black,
  );

  final blocks = <pw.Widget>[];
  var spans = <pw.InlineSpan>[];
  var ordered = 0;

  void endLine(Map<String, dynamic> block) {
    final header = (block['header'] as num?)?.toInt();
    final list = block['list'];
    final indent = ((block['indent'] as num?)?.toInt() ?? 0) * 16.0;
    final size = switch (header) {
      1 => 22.0,
      2 => 18.0,
      3 => 15.0,
      _ => 11.0,
    };
    String? marker;
    if (list == 'ordered') {
      marker = '${++ordered}.';
    } else {
      ordered = 0;
      marker = switch (list) {
        'bullet' => '-',
        'checked' => '[x]',
        'unchecked' => '[ ]',
        _ => null,
      };
    }
    final text = pw.RichText(
      text: pw.TextSpan(
        children: spans.isEmpty ? [pw.TextSpan(text: ' ')] : spans,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: header != null ? pw.FontWeight.bold : null,
        ),
      ),
    );
    spans = [];
    pw.Widget child = marker == null
        ? text
        : pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 24,
                child: pw.Text(marker, style: pw.TextStyle(fontSize: size)),
              ),
              pw.Expanded(child: text),
            ],
          );
    if (block['blockquote'] == true) {
      child = pw.Container(
        padding: const pw.EdgeInsets.only(left: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey500, width: 2),
          ),
        ),
        child: child,
      );
    }
    blocks.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(
          left: indent,
          top: header != null ? 8 : 2,
          bottom: 2,
        ),
        child: child,
      ),
    );
  }

  void addImage(String id) {
    final image = images[id];
    if (image == null) return;
    blocks.add(
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Image(image, fit: pw.BoxFit.contain, height: 260),
      ),
    );
  }

  final inline = inlineImageIds(note.delta);
  for (final id in note.images) {
    if (!inline.contains(id)) addImage(id);
  }
  for (final op in note.delta) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final attributes = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};
    if (insert is Map) {
      if (insert['image'] case final String id) {
        if (spans.isNotEmpty) endLine(const {});
        addImage(id);
      }
      continue;
    }
    if (insert is! String) continue;
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          pw.TextSpan(text: _latin1(parts[i]), style: styleFor(attributes, 11)),
        );
      }
      if (i < parts.length - 1) endLine(attributes);
    }
  }
  if (spans.isNotEmpty) endLine(const {});

  final title = note.title.trim();
  final document = pw.Document(title: _latin1(note.displayTitle));
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (_) => [
        if (title.isNotEmpty)
          pw.Header(
            level: 0,
            child: pw.Text(
              _latin1(title),
              style: pw.TextStyle(fontSize: 26, font: pw.Font.helveticaBold()),
            ),
          ),
        ...blocks,
        if (note.tags.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              _latin1('Tags: ${note.tags.map((t) => '#$t').join(' ')}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
      ],
    ),
  );
  return ExportFile(
    await document.save(),
    '${safeFileName(note.displayTitle)}.pdf',
    'application/pdf',
  );
}
