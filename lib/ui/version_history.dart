import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../data/note.dart';
import '../data/revision.dart';
import '../state/note_editor_store.dart';
import 'note_cards.dart' show noteTime;

/// Lists a note's saved earlier versions. "Restore as a copy" creates a new
/// note and never changes the current one.
Future<void> showVersionHistory(
  BuildContext context,
  NoteEditorStore store,
  Note note,
) => showDialog<void>(
  context: context,
  builder: (context) => _VersionHistory(store: store, note: note),
);

class _VersionHistory extends StatefulWidget {
  const _VersionHistory({required this.store, required this.note});
  final NoteEditorStore store;
  final Note note;

  @override
  State<_VersionHistory> createState() => _VersionHistoryState();
}

class _VersionHistoryState extends State<_VersionHistory> {
  late final Future<List<NoteRevision>> _revisions = widget.store.revisions(
    widget.note.id,
  );
  String? _restoring;

  Future<void> _restore(NoteRevision revision) async {
    setState(() => _restoring = revision.id);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    try {
      final copy = await widget.store.restoreRevision(revision.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            copy == null
                ? l10n.versionHistoryThatVersionIsNoLonger
                : l10n.versionHistoryRestoredAsANewNote(copy.displayTitle),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _restoring = null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.noteCouldNotRestore('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.noteVersionHistory),
    content: SizedBox(
      width: 420,
      child: FutureBuilder<List<NoteRevision>>(
        future: _revisions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              context.l10n.versionHistoryCouldNotLoadVersions(
                '${snapshot.error}',
              ),
            );
          }
          final items = snapshot.data;
          if (items == null) {
            return const Center(
              heightFactor: 2,
              child: CircularProgressIndicator(),
            );
          }
          if (items.isEmpty) {
            return Text(
              context.l10n.versionHistoryNoEarlierVersionsYetBetternotes(
                '$maxRevisionsPerNote',
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final revision in items)
                ExpansionTile(
                  key: ValueKey(revision.id),
                  title: Text(
                    context.l10n.versionHistoryWords(
                      noteTime(revision.createdAt),
                      '${textStats(revision.plainText).words}',
                    ),
                  ),
                  subtitle: Text(
                    revision.title.trim().isNotEmpty
                        ? revision.title.trim()
                        : revision.plainText.trim().split('\n').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  childrenPadding: const EdgeInsets.all(12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Text(
                          revision.plainText.trim().isEmpty
                              ? '(no text)'
                              : revision.plainText.trim(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _restoring == null
                          ? () => _restore(revision)
                          : null,
                      child: Text(context.l10n.versionHistoryRestoreAsACopy),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.reminderClose),
      ),
    ],
  );
}
