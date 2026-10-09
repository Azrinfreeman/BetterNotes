import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'note.dart';

typedef ImageLoader = Future<Uint8List?> Function(
  String noteId,
  String imageId,
);

/// A finished export: a single `.md` file or a ZIP holding notes and images.
class ExportFile {
  const ExportFile(this.bytes, this.name, this.mimeType);
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

String safeFileName(String text, {String fallback = 'note'}) {
  final cleaned = text
      .replaceAll(RegExp(r'[<>:"/\|?*\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final name = cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  return name.isEmpty || name.endsWith('.') ? fallback : name;
}

String _extension(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
  if (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
  if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45) return 'webp';
  return 'png';
}

String _inline(String text, Map<String, dynamic>? attributes) {
  if (text.isEmpty || attributes == null) return text;
  final lead = text.length - text.trimLeft().length;
  final trail = text.length - text.trimRight().length;
  if (lead == text.length) return text;
  var core = text.substring(lead, text.length - trail);
  if (attributes['code'] == true) core = '`$core`';
  if (attributes['bold'] == true) core = '**$core**';
  if (attributes['italic'] == true) core = '*$core*';
  if (attributes['strike'] == true) core = '~~$core~~';
  if (attributes['link'] case final String url when url.isNotEmpty) {
    core = '[$core]($url)';
  }
  return '${text.substring(0, lead)}$core${text.substring(text.length - trail)}';
}

/// Converts a Quill delta to Markdown. [imageName] maps an image ID to the
/// relative path to write for it (null drops the image).
String deltaToMarkdown(
  List<dynamic> delta, {
  String? Function(String imageId)? imageName,
}) {
  final out = StringBuffer();
  final line = StringBuffer();
  final counters = <int, int>{};
  var inCode = false;

  void endLine(Map<String, dynamic> block) {
    final text = line.toString();
    line.clear();
    final indent = '  ' * ((block['indent'] as num?)?.toInt() ?? 0);
    final level = (block['indent'] as num?)?.toInt() ?? 0;
    final isCode = block['code-block'] != null && block['code-block'] != false;
    if (isCode != inCode) {
      out.writeln('```');
      inCode = isCode;
    }
    if (isCode) {
      out.writeln(text);
      return;
    }
    final list = block['list'];
    if (list == 'ordered') {
      counters[level] = (counters[level] ?? 0) + 1;
      out.writeln('$indent${counters[level]}. $text');
      return;
    }
    counters.clear();
    if (list == 'bullet') {
      out.writeln('$indent- $text');
    } else if (list == 'checked') {
      out.writeln('$indent- [x] $text');
    } else if (list == 'unchecked') {
      out.writeln('$indent- [ ] $text');
    } else if (block['header'] case final num header) {
      out.writeln('${'#' * header.toInt().clamp(1, 6)} $text');
    } else if (block['blockquote'] == true) {
      out.writeln('> $text');
    } else {
      out.writeln(text);
    }
  }

  for (final op in delta) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final attributes = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};
    if (insert is Map) {
      final id = insert['image'];
      final path = id is String ? imageName?.call(id) : null;
      if (path != null) line.write('![]($path)');
      continue;
    }
    if (insert is! String) continue;
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      line.write(_inline(parts[i], attributes));
      if (i < parts.length - 1) endLine(attributes);
    }
  }
  if (line.isNotEmpty) endLine(const {});
  if (inCode) out.writeln('```');
  return out.toString().trimRight();
}

/// Builds the Markdown for one note, using [imageName] for image paths.
String noteMarkdown(Note note, {String? Function(String imageId)? imageName}) {
  final body = StringBuffer();
  final inline = inlineImageIds(note.delta);
  final title = note.title.trim();
  if (title.isNotEmpty) body.writeln('# $title\n');
  for (final id in note.images) {
    if (inline.contains(id)) continue;
    final path = imageName?.call(id);
    if (path != null) body.writeln('![]($path)\n');
  }
  body.write(deltaToMarkdown(note.delta, imageName: imageName));
  if (note.tags.isNotEmpty) {
    body.write('\n\nTags: ${note.tags.map((t) => '#$t').join(' ')}');
  }
  return '${body.toString().trimRight()}\n';
}

/// One note without images becomes a plain `.md`; anything else is a ZIP with
/// a Markdown file per note and an `images` folder.
Future<ExportFile> exportMarkdown(
  List<Note> notes,
  ImageLoader loadImage,
) async {
  final archive = Archive();
  final used = <String>{};
  var hasImages = false;
  final files = <String, String>{};
  for (final note in notes) {
    final names = <String, String>{};
    for (final id in {...note.images, ...inlineImageIds(note.delta)}) {
      final bytes = await loadImage(note.id, id);
      if (bytes == null) continue;
      final name =
          'images/${id.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}.${_extension(bytes)}';
      names[id] = name;
      hasImages = true;
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    var base = safeFileName(note.displayTitle);
    var unique = base;
    for (var n = 2; !used.add(unique.toLowerCase()); n++) {
      unique = '$base $n';
    }
    base = unique;
    files['$base.md'] = noteMarkdown(note, imageName: (id) => names[id]);
  }
  if (notes.length == 1 && !hasImages) {
    final entry = files.entries.single;
    return ExportFile(
      Uint8List.fromList(utf8.encode(entry.value)),
      entry.key,
      'text/markdown',
    );
  }
  for (final entry in files.entries) {
    final data = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, data.length, data));
  }
  final date = DateTime.now().toIso8601String().substring(0, 10);
  final name = notes.length == 1
      ? '${files.keys.single.replaceAll(RegExp(r'\.md$'), '')}.zip'
      : 'BetterNotes-markdown-$date.zip';
  return ExportFile(
    Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
    name,
    'application/zip',
  );
}
