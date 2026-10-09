import 'package:flutter/material.dart';

import '../data/note.dart';

/// Edits a note's optional title and comma-separated tags. Returns null when
/// cancelled.
Future<({String title, String tags})?> showNoteDetailsDialog(
  BuildContext context,
  Note note, {
  List<String> suggestions = const [],
}) async {
  final title = TextEditingController(text: note.title);
  final tags = TextEditingController(text: note.tags.join(', '));
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Title and tags'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('note-title'),
                controller: title,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'Uses the first text line when blank',
                ),
              ),
              TextField(
                key: const ValueKey('note-tags'),
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'work, ideas, personal',
                ),
              ),
              if (suggestions.isNotEmpty)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: tags,
                  builder: (context, value, _) {
                    final entries = value.text.split(',');
                    final typing = entries.last.trim().toLowerCase();
                    final used = normalizeTags(
                      entries.take(entries.length - 1),
                    );
                    final options = [
                      for (final tag in suggestions)
                        if (!used.contains(tag) && tag.contains(typing)) tag,
                    ].take(12);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final tag in options)
                            ActionChip(
                              label: Text(tag),
                              onPressed: () {
                                final text = [
                                  ...entries
                                      .take(entries.length - 1)
                                      .map((e) => e.trim())
                                      .where((e) => e.isNotEmpty),
                                  tag,
                                ].join(', ');
                                tags.value = TextEditingValue(
                                  text: '$text, ',
                                  selection: TextSelection.collapsed(
                                    offset: text.length + 2,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted != true) return null;
    return (title: title.text, tags: tags.text);
  } finally {
    // Let the dialog finish its closing animation before disposing fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    tags.dispose();
  }
}
