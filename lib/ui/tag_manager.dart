import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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
        title: Text(context.l10n.notesHomeManageTags),
        content: SizedBox(
          width: 360,
          child: tags.isEmpty
              ? Text(context.l10n.tagManagerNoTagsYetAddTags)
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
                              tooltip: context.l10n.tagManagerRenameOrMerge(
                                tag,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _rename(context, controller, tag),
                            ),
                            IconButton(
                              tooltip: context.l10n.tagManagerDeleteTag3(tag),
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
            child: Text(context.l10n.reminderDone),
          ),
        ],
      );
    },
  ),
);

void _report(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.tagManagerCouldNotChangeTag('$error')),
      ),
    );

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
        title: Text(context.l10n.tagManagerRename(tag)),
        content: TextField(
          key: const ValueKey('tag-rename'),
          controller: field,
          autofocus: true,
          decoration: InputDecoration(
            helperText: context.l10n.tagManagerUsingAnExistingTagName,
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.bulkCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(context.l10n.tagManagerRename2),
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
      title: Text(context.l10n.tagManagerDeleteTag(tag)),
      content: Text(context.l10n.tagManagerTheTagIsRemovedFrom),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.bulkCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.tagManagerDeleteTag2),
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
