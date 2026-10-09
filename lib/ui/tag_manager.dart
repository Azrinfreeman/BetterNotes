import 'package:flutter/material.dart';

import '../state/notes_controller.dart';

/// Lists every tag with its note count; rename (merging into an existing tag
/// when the name matches) or delete a tag across all notes.
Future<void> showTagManager(
  BuildContext context,
  NotesController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final counts = controller.tagCounts;
      final tags = counts.keys.toList()..sort();
      return AlertDialog(
        title: const Text('Manage tags'),
        content: SizedBox(
          width: 360,
          child: tags.isEmpty
              ? const Text('No tags yet. Add tags from a note’s menu.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tag in tags)
                      ListTile(
                        title: Text(tag),
                        subtitle: Text(
                          '${counts[tag]} note${counts[tag] == 1 ? '' : 's'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rename or merge $tag',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _rename(context, controller, tag),
                            ),
                            IconButton(
                              tooltip: 'Delete tag $tag',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _delete(context, controller, tag),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  ),
);

void _report(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not change tag: $error')));

Future<void> _rename(
  BuildContext context,
  NotesController controller,
  String tag,
) async {
  final field = TextEditingController(text: tag);
  try {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename “$tag”'),
        content: TextField(
          key: const ValueKey('tag-rename'),
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'Using an existing tag name merges the two.',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await controller.renameTag(tag, name);
  } catch (error) {
    if (context.mounted) _report(context, error);
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
  }
}

Future<void> _delete(
  BuildContext context,
  NotesController controller,
  String tag,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete tag “$tag”?'),
      content: const Text('The tag is removed from every note. Notes stay.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete tag'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await controller.deleteTag(tag);
  } catch (error) {
    if (context.mounted) _report(context, error);
  }
}
