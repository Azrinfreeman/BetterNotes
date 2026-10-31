import 'package:flutter/services.dart';
import 'package:flutter_quill/quill_delta.dart';

class TextCleanupOptions {
  const TextCleanupOptions({
    this.trailingSpaces = true,
    this.blankLines = true,
    this.repeatedSpaces = false,
  });
  final bool trailingSpaces;
  final bool blankLines;
  final bool repeatedSpaces;
}

class TextCleanupResult {
  const TextCleanupResult(
    this.change,
    this.preview,
    this.selection,
    this.spacesRemoved,
    this.blankLinesRemoved,
  );
  final Delta change;
  final Delta preview;
  final TextSelection selection;
  final int spacesRemoved;
  final int blankLinesRemoved;
  bool get hasChanges => spacesRemoved + blankLinesRemoved > 0;
}

/// Plans deletions against UTF-16 document offsets, retaining surviving styles.
TextCleanupResult planTextCleanup(
  Delta snapshot,
  TextSelection selection, [
  TextCleanupOptions options = const TextCleanupOptions(),
]) {
  final units = <int>[];
  final attributes = <Map<String, dynamic>>[];
  final embeds = <int>{};
  for (final op in snapshot.toList()) {
    final data = op.data;
    final chars = data is String ? data.codeUnits : [0xfffc];
    if (data is! String) embeds.add(units.length);
    units.addAll(chars);
    attributes.addAll(List.filled(chars.length, op.attributes ?? {}));
  }
  final length = units.length;
  final start = selection.isValid && !selection.isCollapsed
      ? selection.start
      : 0;
  final end = selection.isValid && !selection.isCollapsed
      ? selection.end
      : length;
  final removed = List.filled(length, false);
  var spaces = 0;
  var blanks = 0;
  bool inside(int a, int b) => a >= start && b <= end;
  bool code(int i) => i >= 0 && i < length && attributes[i]['code'] == true;
  bool safe(int a, int b) {
    for (var i = a - 1; i <= b; i++) {
      if (code(i)) return false;
    }
    return true;
  }

  void removeSpaces(int a, int b) {
    for (var i = a; i < b; i++) {
      if (!removed[i]) {
        removed[i] = true;
        spaces++;
      }
    }
  }

  final emptyParagraphs = <({int start, int end})>[];
  void finishBlankRun() {
    // Keep the last blank paragraph, including the mandatory final newline.
    if (options.blankLines && emptyParagraphs.length > 1) {
      for (final line in emptyParagraphs.take(emptyParagraphs.length - 1)) {
        if (!inside(line.start, line.end + 1)) continue;
        for (var i = line.start; i <= line.end; i++) {
          if (removed[i]) spaces--;
          removed[i] = true;
        }
        blanks++;
      }
    }
    emptyParagraphs.clear();
  }

  var lineStart = 0;
  for (var newline = 0; newline < length; newline++) {
    if (units[newline] != 10) continue;
    var eligible = attributes[newline].isEmpty;
    var styled = attributes[newline].isNotEmpty;
    for (var i = lineStart; i < newline; i++) {
      if (embeds.contains(i)) eligible = false;
      if (attributes[i].isNotEmpty) styled = true;
    }
    if (eligible) {
      var trailing = newline;
      while (trailing > lineStart && units[trailing - 1] == 32) {
        trailing--;
      }
      if (options.trailingSpaces &&
          trailing < newline &&
          inside(trailing, newline + 1) &&
          safe(trailing, newline)) {
        removeSpaces(trailing, newline);
      }
      if (options.repeatedSpaces) {
        var i = lineStart;
        while (i < newline) {
          if (units[i] != 32) {
            i++;
            continue;
          }
          final a = i;
          while (i < newline && units[i] == 32) {
            i++;
          }
          bool word(int index) => !RegExp(
            r'\s',
            unicode: true,
          ).hasMatch(String.fromCharCode(units[index]));
          if (i - a > 1 &&
              a > lineStart &&
              i < newline &&
              word(a - 1) &&
              word(i) &&
              inside(a - 1, i + 1) &&
              safe(a, i)) {
            removeSpaces(a + 1, i);
          }
        }
      }
    }
    final empty =
        eligible &&
        !styled &&
        Iterable.generate(
          newline - lineStart,
          (i) => lineStart + i,
        ).every((i) => removed[i]);
    if (empty) {
      emptyParagraphs.add((start: lineStart, end: newline));
    } else {
      finishBlankRun();
    }
    lineStart = newline + 1;
  }
  finishBlankRun();
  final change = Delta();
  var retained = 0;
  for (var i = 0; i < length; i++) {
    if (removed[i]) {
      if (retained > 0) {
        change.retain(retained);
        retained = 0;
      }
      change.delete(1);
    } else {
      retained++;
    }
  }
  final mapped = selection.isValid
      ? selection.copyWith(
          baseOffset: change.transformPosition(selection.baseOffset),
          extentOffset: change.transformPosition(selection.extentOffset),
        )
      : const TextSelection.collapsed(offset: 0);
  return TextCleanupResult(
    change,
    snapshot.compose(change),
    mapped,
    spaces,
    blanks,
  );
}
