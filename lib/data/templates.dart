/// Built-in starting points for New note > From template.
class NoteTemplate {
  const NoteTemplate(this.id, this.name, this.title, this.lines);

  final String id;
  final String name;
  final String title;

  /// Each entry is `[ ] task`, `# heading`, or a plain paragraph.
  final List<String> lines;

  /// Quill delta operations for this template.
  List<Map<String, dynamic>> get delta {
    final ops = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.startsWith('[ ] ')) {
        ops
          ..add({'insert': line.substring(4)})
          ..add({
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          });
      } else if (line.startsWith('# ')) {
        ops
          ..add({'insert': line.substring(2)})
          ..add({
            'insert': '\n',
            'attributes': {'header': 2},
          });
      } else {
        ops.add({'insert': '$line\n'});
      }
    }
    return ops.isEmpty
        ? [
            {'insert': '\n'},
          ]
        : ops;
  }

  String get plainText => lines
      .map(
        (line) => line.startsWith('[ ] ')
            ? line.substring(4)
            : line.startsWith('# ')
            ? line.substring(2)
            : line,
      )
      .join('\n');
}

const noteTemplates = <NoteTemplate>[
  NoteTemplate('daily', 'Daily tasks', 'Today', [
    '# Top priorities',
    '[ ] ',
    '[ ] ',
    '[ ] ',
    '# Other tasks',
    '[ ] ',
    '[ ] ',
  ]),
  NoteTemplate('meeting', 'Meeting', 'Meeting notes', [
    '# Attendees',
    '',
    '# Agenda',
    '',
    '# Decisions',
    '',
    '# Action items',
    '[ ] ',
  ]),
  NoteTemplate('idea', 'Idea', 'Idea', [
    '# The idea',
    '',
    '# Why it matters',
    '',
    '# Next step',
    '[ ] ',
  ]),
  NoteTemplate('shopping', 'Shopping list', 'Shopping', [
    '[ ] ',
    '[ ] ',
    '[ ] ',
    '[ ] ',
  ]),
];
