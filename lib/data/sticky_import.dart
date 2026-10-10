import 'dart:typed_data';

/// One note read from Windows Sticky Notes (its `plum.sqlite` database).
class StickyNote {
  const StickyNote({
    required this.id,
    required this.text,
    required this.theme,
    required this.createdAt,
    required this.updatedAt,
    this.mediaFiles = const [],
  });

  final String id;

  /// The raw stored text: `\id=<GUID> line` per line, RTF-like inline codes.
  final String text;
  final String theme;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Picture file names (inside the Sticky Notes `media` folder), oldest first.
  final List<String> mediaFiles;
}

/// Converts a .NET tick count (100 ns since 0001-01-01 UTC) to a UTC time.
DateTime? stickyTimeFromTicks(int? ticks) {
  if (ticks == null || ticks <= 0) return null;
  const epochTicks = 621355968000000000; // 1970-01-01
  return DateTime.fromMicrosecondsSinceEpoch(
    (ticks - epochTicks) ~/ 10,
    isUtc: true,
  );
}

/// Index into BetterNotes' 12 named colors for a Sticky Notes theme.
int stickyColorIndex(String? theme) => switch (theme?.toLowerCase()) {
  'yellow' => 0, // Lemon
  'pink' => 4, // Rose
  'blue' => 5, // Cloud
  'green' => 3, // Mint
  'purple' => 2, // Lilac
  'gray' || 'grey' => 11, // Silver
  'charcoal' => 11, // no dark color here; nearest neutral
  _ => 0,
};

/// The note body as a Quill delta plus plain text.
class StickyContent {
  const StickyContent(this.delta, this.plainText);
  final List<Map<String, dynamic>> delta;
  final String plainText;
}

final _linePrefix = RegExp(r'^\\id=[0-9a-fA-F-]{36} ?');

/// Parses Sticky Notes text. Each line may start with `\id=<GUID> `; inline
/// codes `\b`/`\b0` (bold), `\i`/`\i0` (italic), `\ul`/`\ul0` (underline) and
/// `\strike`/`\strike0` toggle formatting, `\\` is a literal backslash, and a
/// single space after a code is its delimiter. Unknown backslash sequences are
/// kept as text.
StickyContent parseStickyText(String raw) {
  final delta = <Map<String, dynamic>>[];
  final plain = StringBuffer();
  final lines = raw.split(RegExp(r'\r\n|\r|\n'));
  var bold = false, italic = false, underline = false, strike = false;

  void emit(String text) {
    if (text.isEmpty) return;
    final attributes = <String, dynamic>{
      if (bold) 'bold': true,
      if (italic) 'italic': true,
      if (underline) 'underline': true,
      if (strike) 'strike': true,
    };
    if (delta.isNotEmpty &&
        delta.last['insert'] is String &&
        _sameAttributes(delta.last['attributes'], attributes)) {
      delta.last['insert'] = (delta.last['insert'] as String) + text;
    } else {
      delta.add({
        'insert': text,
        if (attributes.isNotEmpty) 'attributes': attributes,
      });
    }
    plain.write(text);
  }

  const words = {
    'b': 'bold',
    'i': 'italic',
    'ul': 'underline',
    'strike': 'strike',
  };

  for (var index = 0; index < lines.length; index++) {
    // Each line stands alone: its codes never carry into the next paragraph.
    bold = italic = underline = strike = false;
    final line = lines[index].replaceFirst(_linePrefix, '');
    var buffer = StringBuffer();
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (c != r'\') {
        buffer.write(c);
        i++;
        continue;
      }
      if (i + 1 < line.length && line[i + 1] == r'\') {
        buffer.write(r'\');
        i += 2;
        continue;
      }
      final match = RegExp(r'^\\(strike|ul|b|i)(0?)(?![A-Za-z0-9])')
          .firstMatch(line.substring(i));
      if (match == null) {
        buffer.write(c);
        i++;
        continue;
      }
      emit(buffer.toString());
      buffer = StringBuffer();
      final on = match.group(2)!.isEmpty;
      switch (words[match.group(1)]) {
        case 'bold':
          bold = on;
        case 'italic':
          italic = on;
        case 'underline':
          underline = on;
        case 'strike':
          strike = on;
      }
      i += match.group(0)!.length;
      if (i < line.length && line[i] == ' ') i++; // the code's delimiter
    }
    emit(buffer.toString());
    // Formatting never continues across paragraphs.
    delta.add({'insert': '\n'});
    plain.write('\n');
  }
  if (delta.isEmpty || delta.last['insert'] != '\n') {
    delta.add({'insert': '\n'});
  }
  return StickyContent(delta, plain.toString());
}

bool _sameAttributes(Object? a, Map<String, dynamic> b) {
  final left = (a as Map?)?.keys.toSet() ?? <Object?>{};
  return left.length == b.length && left.containsAll(b.keys);
}

class StickyImportResult {
  const StickyImportResult({
    required this.found,
    required this.imported,
    required this.alreadyImported,
    required this.empty,
    required this.pictures,
    required this.failedPictures,
  });

  final int found;
  final int imported;
  final int alreadyImported;
  final int empty;
  final int pictures;
  final int failedPictures;
}

/// Source of Sticky Notes data, so the import can be tested without Windows.
abstract class StickySource {
  Future<List<StickyNote>> notes();
  Future<Uint8List?> media(String fileName);
}
