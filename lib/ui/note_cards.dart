import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import '../data/note.dart';
import '../l10n/l10n.dart';
import 'theme/notes_theme.dart';
import '../state/note_editor_store.dart';
import '../state/notes_controller.dart';
import 'note_page.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.searching,
    required this.onCreate,
    this.message,
    this.onReset,
  });
  final bool searching;
  final VoidCallback onCreate;
  final String? message;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.sticky_note_2_outlined,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            message ??
                (searching
                    ? context.l10n.noteNoMatchingNotes
                    : context.l10n.noteAFreshSpaceForYour),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? context.l10n.noteTryAnotherWordOrClear
                : message != null
                ? context.l10n.noteChooseAnotherViewOrReset
                : context.l10n.noteKeepAThoughtCloseStart,
            textAlign: TextAlign.center,
          ),
          if (onReset != null)
            TextButton(
              onPressed: onReset,
              child: Text(context.l10n.noteShowAllNotes),
            ),
          if (!searching && message == null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.noteCreateANote),
            ),
          ],
        ],
      ),
    ),
  );
}

class TrashCard extends StatelessWidget {
  const TrashCard({super.key, required this.note, required this.controller});
  final Note note;
  final NotesController controller;

  Future<void> _command(BuildContext context, bool permanent) async {
    if (permanent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.notePermanentlyDeleteThisNote),
          content: Text(context.l10n.noteThisCannotBeUndoneA),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.bulkCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.noteDeletePermanently),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (permanent) {
        await controller.purge(note.id);
      } else {
        await controller.restore(note.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permanent
                  ? context.l10n.noteNotePermanentlyDeleted
                  : context.l10n.noteNoteRestoredToNotes,
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey(note.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.deletedAt == null
                ? context.l10n.noteInTrash
                : context.l10n.noteDeleted(noteTime(note.deletedAt!)),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.displayTitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _command(context, false),
                icon: const Icon(Icons.restore),
                label: Text(context.l10n.noteRestore),
              ),
              IconButton(
                tooltip: note.ownerId == guestOwner
                    ? context.l10n.noteDeletePermanently
                    : context.l10n.noteAccountTrashRetainsSyncRecords,
                onPressed: note.ownerId == guestOwner
                    ? () => _command(context, true)
                    : null,
                icon: const Icon(Icons.delete_forever_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ArchiveCard extends StatelessWidget {
  const ArchiveCard({super.key, required this.note, required this.controller});
  final Note note;
  final NotesController controller;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey(note.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.plainText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await controller.archive(note.id, archived: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.noteNoteRestoredFromArchive),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.noteCouldNotRestore('$error')),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.unarchive_outlined),
            label: Text(context.l10n.noteRestoreFromArchive),
          ),
        ],
      ),
    ),
  );
}

/// One dense row for the compact list view: color strip, title, a snippet
/// with tags, and a star for favorites.
class CompactNoteTile extends StatelessWidget {
  const CompactNoteTile({
    super.key,
    required this.note,
    required this.onOpen,
    this.selected = false,
    this.sort = NoteSort.updated,
  });
  final Note note;
  final VoidCallback onOpen;
  final bool selected;
  final NoteSort sort;

  @override
  Widget build(BuildContext context) {
    final color = noteSurface(context, note.colorIndex);
    final scheme = Theme.of(context).colorScheme;
    final snippet = note.title.trim().isEmpty
        ? note.plainText.trimLeft().split('\n').skip(1).join(' ').trim()
        : note.plainText.replaceAll('\n', ' ').trim();
    final detail = [
      noteDateLabel(note, sort),
      if (note.tasks.total > 0) '${note.tasks.done}/${note.tasks.total} tasks',
      ?reminderLabel(note),
      if (note.tags.isNotEmpty) note.tags.join(', '),
      if (snippet.isNotEmpty) snippet,
    ].join(' · ');
    return Semantics(
      container: true,
      label: context.l10n.noteUpdatedNote(
        note.displayTitle,
        noteTime(note.updatedAt),
        noteColorNames[note.colorIndex % noteColorNames.length],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected ? scheme.primaryContainer : color,
        child: InkWell(
          onTap: onOpen,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (note.favorite)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.star,
                    size: 20,
                    semanticLabel: context.l10n.noteFavorite,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.controller,
    this.onOpen,
    this.sort = NoteSort.updated,
  });
  final Note note;
  final NotesController controller;
  final VoidCallback? onOpen;
  final NoteSort sort;

  @override
  Widget build(BuildContext context) {
    final color = noteSurface(context, note.colorIndex);
    final preview = note.title.trim().isEmpty
        ? note.plainText.trimLeft().split('\n').skip(1).join('\n')
        : note.plainText;
    return Semantics(
      container: true,
      label: context.l10n.noteUpdatedNote2(
        note.displayTitle,
        preview,
        noteTime(note.updatedAt),
        noteColorNames[note.colorIndex % noteColorNames.length],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: color,
        child: InkWell(
          onTap:
              onOpen ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NotePage(controller: controller, noteId: note.id),
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: context.l10n.noteNoteOptions,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) async {
                        if (value == -2 || value == -3 || value == -4) {
                          try {
                            if (value == -2) {
                              await controller.save(
                                note.copyWith(favorite: !note.favorite),
                              );
                            } else if (value == -4) {
                              await controller.duplicate(note.id);
                            } else {
                              await controller.archive(note.id);
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.noteCouldNotUpdateNote(
                                      '$error',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                          return;
                        }
                        if (value >= 0) {
                          await controller.save(
                            note.copyWith(colorIndex: value),
                          );
                          return;
                        }
                        if (controller.confirmDelete) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.l10n.noteDeleteThisNote),
                              content: Text(
                                context.l10n.noteMoveThisNoteToTrash,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(context.l10n.bulkCancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(context.l10n.noteDelete),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }
                        try {
                          await controller.flushAllEditors();
                          await controller.delete(note);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.noteCouldNotMoveToTrash(
                                    '$error',
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<int>(
                          value: -2,
                          child: Text(
                            note.favorite
                                ? context.l10n.notesHomeRemoveFavorite
                                : 'Favorite',
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: -4,
                          child: Text(context.l10n.noteDuplicateNote),
                        ),
                        PopupMenuItem<int>(
                          value: -3,
                          child: Text(context.l10n.noteArchiveNote),
                        ),
                        const PopupMenuDivider(),
                        for (var i = 0; i < noteColors.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Color(noteColors[i]),
                                ),
                                const SizedBox(width: 10),
                                Text(noteColorNames[i]),
                                if (note.colorIndex == i) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check, size: 18),
                                ],
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem<int>(
                          value: -1,
                          child: Text(context.l10n.noteDeleteNote),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (note.favorite)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          semanticLabel: context.l10n.noteFavorite,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        noteDateLabel(note, sort),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (note.tasks.total > 0 ||
                  note.tags.isNotEmpty ||
                  note.remindAt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    [
                      if (note.tasks.total > 0)
                        '${note.tasks.done}/${note.tasks.total} tasks',
                      ?reminderLabel(note),
                      if (note.tags.isNotEmpty) note.tags.join(', '),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              if (note.images.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: NoteImage(
                      controller: controller,
                      noteId: note.id,
                      imageId: note.images.first,
                      fit: BoxFit.cover,
                      thumbnail: true,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Text(
                    preview,
                    maxLines: note.images.isEmpty ? 6 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: note.plainText.isEmpty
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date and time for reminders: context.l10n.noteTodayAm, "Tomorrow 9:00 AM", "12 Oct 9:00 AM".
String reminderTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final l10n = currentL10n();
  final clock = DateFormat.jm().format(local);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return l10n.reminderToday(clock);
  if (diff == 1) return l10n.reminderTomorrow(clock);
  final dayText = local.year == now.year
      ? DateFormat.MMMd().format(local)
      : DateFormat.yMMMd().format(local);
  return l10n.reminderOn(dayText, clock);
}

/// Short reminder text for cards, or null when the note has none.
String? reminderLabel(Note note) {
  final at = note.remindAt;
  if (at == null) return null;
  final l10n = currentL10n();
  return note.reminderFired
      ? l10n.reminderCardShown(reminderTime(at))
      : l10n.reminderCardLabel(reminderTime(at));
}

/// The date shown on a card: the creation date when sorting by creation,
/// otherwise the last edit.
String noteDateLabel(Note note, NoteSort sort) =>
    sort == NoteSort.created || sort == NoteSort.createdOldest
    ? currentL10n().cardCreated(noteTime(note.createdAt))
    : noteTime(note.updatedAt);

String noteTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return DateFormat.jm().format(local);
  }
  return DateFormat.MMMd().format(local);
}

class NoteImage extends StatefulWidget {
  const NoteImage({
    super.key,
    required this.controller,
    required this.noteId,
    required this.imageId,
    this.fit = BoxFit.contain,
    this.thumbnail = false,
  });

  final NoteEditorStore controller;
  final String noteId;
  final String imageId;
  final BoxFit fit;
  final bool thumbnail;

  @override
  State<NoteImage> createState() => _NoteImageState();
}

class _NoteImageState extends State<NoteImage> {
  late Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    _image = widget.controller.image(widget.noteId, widget.imageId);
  }

  @override
  void didUpdateWidget(NoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId ||
        oldWidget.imageId != widget.imageId) {
      _image = widget.controller.image(widget.noteId, widget.imageId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Center(
          child: Icon(
            Icons.image_outlined,
            semanticLabel: context.l10n.noteLoadingImage,
          ),
        );
      }
      if (!snapshot.hasData || snapshot.hasError) return _unavailableImage();
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: double.infinity,
          cacheHeight: widget.thumbnail
              ? (72 * MediaQuery.devicePixelRatioOf(context)).ceil()
              : null,
          semanticLabel: context.l10n.noteAttachedNoteImage,
          errorBuilder: (_, _, _) => _unavailableImage(),
        ),
      );
    },
  );

  Widget _unavailableImage() => Center(
    child: widget.thumbnail
        ? Tooltip(
            message: context.l10n.noteImageUnavailableOpenTheNote,
            child: Icon(
              Icons.broken_image_outlined,
              semanticLabel: context.l10n.noteImageUnavailable,
            ),
          )
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.noteImageUnavailable,
                  textAlign: TextAlign.center,
                ),
                Text(
                  context.l10n.noteRetryLoadingOrRestoreA,
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _image = widget.controller.image(
                      widget.noteId,
                      widget.imageId,
                    );
                  }),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.noteRetryImage),
                ),
              ],
            ),
          ),
  );
}
