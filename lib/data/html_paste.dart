import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

const _maxHtmlBytes = 2 * 1024 * 1024;

/// Extracts the copied fragment from a Windows "HTML Format" clipboard value.
String? htmlFragmentFromClipboard(String raw) {
  const start = '<!--StartFragment-->';
  const end = '<!--EndFragment-->';
  final from = raw.indexOf(start);
  final to = raw.lastIndexOf(end);
  if (from >= 0 && to > from) return raw.substring(from + start.length, to);
  final body = raw.indexOf('<');
  return body < 0 ? null : raw.substring(body);
}

/// Converts pasted HTML to note formatting. Returns null when nothing
/// usable results, so the caller can fall back to plain text. Fonts, sizes,
/// pictures and other source-specific styling are dropped on purpose.
Delta? htmlToNoteDelta(String html) {
  if (html.isEmpty || utf8.encode(html).length > _maxHtmlBytes) return null;
  try {
    final cleaned = html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(
          RegExp(
            r'<(script|style|head)\b.*?</\1>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ');
    final converted = HtmlToDelta().convert(cleaned);
    final result = Delta();
    for (final op in converted.toList()) {
      final data = op.data;
      if (data is! String) continue;
      final attributes = op.attributes == null
          ? null
          : <String, dynamic>{
              for (final entry in op.attributes!.entries)
                if (!_dropped.contains(entry.key)) entry.key: entry.value,
            };
      result.insert(
        data.replaceAll(' ', ' '),
        attributes == null || attributes.isEmpty ? null : attributes,
      );
    }
    if (result.isEmpty) return null;
    // Drop the trailing block break; the editor already owns the final newline.
    final last = result.last;
    if (last.data == '\n' && last.attributes == null) {
      final trimmed = Delta();
      final ops = result.toList();
      for (var i = 0; i < ops.length - 1; i++) {
        trimmed.insert(ops[i].data, ops[i].attributes);
      }
      if (trimmed.isEmpty) return null;
      return trimmed;
    }
    return result;
  } catch (_) {
    return null;
  }
}

const _dropped = {
  'size',
  'font',
  'line-height',
  'align',
  'direction',
  'script',
};

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// HTML fragment for other programs (Word, mail, browsers) from a selection.
String deltaToHtml(Delta delta) {
  final out = StringBuffer();
  final line = StringBuffer();
  String? openList;
  void closeList() {
    if (openList != null) out.write('</$openList>');
    openList = null;
  }

  String inline(String text, Map<String, dynamic>? a) {
    var s = _escape(text);
    if (a == null) return s;
    if (a['bold'] == true) s = '<b>$s</b>';
    if (a['italic'] == true) s = '<i>$s</i>';
    if (a['underline'] == true) s = '<u>$s</u>';
    if (a['strike'] == true) s = '<s>$s</s>';
    if (a['code'] == true) s = '<code>$s</code>';
    final style = [
      if (a['color'] is String) 'color:${a['color']}',
      if (a['background'] is String) 'background-color:${a['background']}',
    ];
    if (style.isNotEmpty) s = '<span style="${style.join(';')}">$s</span>';
    if (a['link'] is String) {
      s = '<a href="${_escape(a['link'] as String).replaceAll('"', '&quot;')}">$s</a>';
    }
    return s;
  }

  void endLine(Map<String, dynamic>? block) {
    final html = line.toString();
    line.clear();
    final list = block?['list'];
    if (list != null) {
      final tag = list == 'ordered' ? 'ol' : 'ul';
      if (openList != tag) {
        closeList();
        out.write('<$tag>');
        openList = tag;
      }
      out.write('<li>$html</li>');
      return;
    }
    closeList();
    final header = block?['header'];
    if (header is int && header >= 1 && header <= 6) {
      out.write('<h$header>$html</h$header>');
    } else if (block?['blockquote'] == true) {
      out.write('<blockquote>$html</blockquote>');
    } else if (block?['code-block'] != null) {
      out.write('<pre>$html</pre>');
    } else {
      out.write('<p>$html</p>');
    }
  }

  for (final op in delta.toList()) {
    final data = op.data;
    if (data is! String) continue;
    final parts = data.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) line.write(inline(parts[i], op.attributes));
      if (i < parts.length - 1) endLine(op.attributes);
    }
  }
  if (line.isNotEmpty) endLine(null);
  closeList();
  return out.toString();
}

/// Wraps a fragment in the Windows "HTML Format" header (byte offsets).
String clipboardHtml(String fragment) {
  const pre = '<html><body>\r\n<!--StartFragment-->';
  const post = '<!--EndFragment-->\r\n</body></html>';
  String header(int a, int b, int c, int d) =>
      'Version:0.9\r\nStartHTML:${a.toString().padLeft(10, '0')}\r\n'
      'EndHTML:${b.toString().padLeft(10, '0')}\r\n'
      'StartFragment:${c.toString().padLeft(10, '0')}\r\n'
      'EndFragment:${d.toString().padLeft(10, '0')}\r\n';
  final h = utf8.encode(header(0, 0, 0, 0)).length;
  final p = utf8.encode(pre).length;
  final f = utf8.encode(fragment).length;
  final t = utf8.encode(post).length;
  return header(h, h + p + f + t, h + p, h + p + f) + pre + fragment + post;
}
