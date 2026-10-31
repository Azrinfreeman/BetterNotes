import 'package:better_notes/data/html_paste.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows clipboard HTML keeps only the copied fragment', () {
    final raw = clipboardHtml('<b>Hi</b>');
    expect(htmlFragmentFromClipboard(raw), '<b>Hi</b>');
    expect(raw, startsWith('Version:0.9'));
  });

  test('formatting converts; fonts, sizes, scripts and styles are dropped', () {
    final delta = htmlToNoteDelta(
      '<style>p{color:red}</style><script>x()</script>'
      '<p>Plain <b>bold</b> <i>it</i> <a href="https://a.test">link</a> '
      '<span style="font-size:30px;font-family:Arial">sized</span></p>'
      '<ul><li>one</li><li>two</li></ul>',
    )!;
    final json = delta.toJson().toString();
    expect(json, contains('bold: true'));
    expect(json, contains('italic: true'));
    expect(json, contains('link: https://a.test'));
    expect(json, contains('list: bullet'));
    expect(json, isNot(contains('size:')));
    expect(json, isNot(contains('font:')));
    expect(json, isNot(contains('x()')));
    expect(json, isNot(contains('color:red')));
  });

  test('words split across source lines keep their spaces', () {
    final delta = htmlToNoteDelta('<p>one\ntwo</p>')!;
    expect(delta.toJson().map((o) => o['insert']).join(), contains('one two'));
  });

  test('junk, empty and oversized input fall back to plain text', () {
    expect(htmlToNoteDelta(''), isNull);
    expect(htmlToNoteDelta('<script>a</script>'), isNull);
    expect(htmlToNoteDelta('x' * (3 * 1024 * 1024)), isNull);
  });

  test('copying out writes HTML other programs understand', () {
    final html = deltaToHtml(
      Delta.fromJson([
        {
          'insert': 'Bold',
          'attributes': {'bold': true},
        },
        {'insert': ' & <text>\nitem'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]),
    );
    expect(html, contains('<b>Bold</b>'));
    expect(html, contains('&amp; &lt;text&gt;'));
    expect(html, contains('<ul><li>item</li></ul>'));
  });
}
