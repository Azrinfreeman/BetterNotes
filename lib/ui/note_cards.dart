import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note.dart';
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
                    ? 'No matching notes'
                    : 'A fresh space for your ideas'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Try another word or clear the search.'
                : message != null
                ? 'Choose another view or reset filters to see your notes.'
                : 'Keep a thought close. Start with a note.',
            textAlign: TextAlign.center,
          ),
          if (onReset != null)
            TextButton(onPressed: onReset, child: const Text('Show all notes')),
          if (!searching && message == null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create a note'),
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
          title: const Text('Permanently delete this note?'),
          content: const Text(
            'This cannot be undone. A previously exported backup will keep its copy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
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
              permanent ? 'Note permanently deleted' : 'Note restored to Notes',
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
                ? 'In Trash'
                : 'Deleted ${noteTime(note.deletedAt!)}',
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
                label: const Text('Restore'),
              ),
              IconButton(
                tooltip: note.ownerId == guestOwner
                    ? 'Delete permanently'
                    : 'Account Trash retains sync records',
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
                    const SnackBar(content: Text('Note restored from Archive')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not restore: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Restore from Archive'),
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
  });
  final Note note;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Color(noteColors[note.colorIndex % noteColors.length]);
    final scheme = Theme.of(context).colorScheme;
    final snippet = note.title.trim().isEmpty
        ? note.plainText.trimLeft().split('\n').skip(1).join(' ').trim()
        : note.plainText.replaceAll('\n', ' ').trim();
    final detail = [
      noteTime(note.updatedAt),
      if (note.tasks.total > 0) '${note.tasks.done}/${note.tasks.total} tasks',
      ?reminderLabel(note),
      if (note.tags.isNotEmpty) note.tags.join(', '),
      if (snippet.isNotEmpty) snippet,
    ].join(' · ');
    return Semantics(
      container: true,
      label:
          '${note.displayTitle}. Updated ${noteTime(note.updatedAt)}. '
          '${noteColorNames[note.colorIndex % noteColorNames.length]} note.',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected ? scheme.primaryContainer : null,
        child: InkWell(
          onTap: onOpen,
          child: Row(
            children: [
              Container(width: 8, color: color),
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
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.star, size: 20, semanticLabel: 'Favorite'),
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
  });
  final Note note;
  final NotesController controller;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = Color(noteColors[note.colorIndex % noteColors.length]);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final preview = note.title.trim().isEmpty
        ? note.plainText.trimLeft().split('\n').skip(1).join('\n')
        : note.plainText;
    return Semantics(
      container: true,
      label:
          '${note.displayTitle}. $preview. Updated ${noteTime(note.updatedAt)}. '
          '${noteColorNames[note.colorIndex % noteColorNames.length]} note.',
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: dark ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
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
              Container(height: 7, color: color),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        noteTime(note.updatedAt),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Note options',
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
                                    'Could not update note: $error',
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
                              title: const Text('Delete this note?'),
                              content: const Text(
                                'Move this note to Trash? You can restore it later.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
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
                                  'Could not move to Trash: $error',
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
                            note.favorite ? 'Remove favorite' : 'Favorite',
                          ),
                        ),
                        const PopupMenuItem<int>(
                          value: -4,
                          child: Text('Duplicate note'),
                        ),
                        const PopupMenuItem<int>(
                          value: -3,
                          child: Text('Archive note'),
                        ),
                        const PopupMenuDivider(),
                        for (var i = 0; i < noteColors.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(noteColors[i]),
                                ),
                                const SizedBox(width: 10),
                                Text(noteColorNames[i]),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<int>(
                          value: -1,
                          child: Text('Delete note'),
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
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          semanticLabel: 'Favorite',
                        ),
                      ),
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
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

/// Date and time for reminders: "Today 9:00 AM", "Tomorrow 9:00 AM", "12 Oct 9:00 AM".
String reminderTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final clock =
      '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today $clock';
  if (diff == 1) return 'Tomorrow $clock';
  final year = local.year == now.year ? '' : ' ${local.year}';
  return '${local.day} ${_months[local.month - 1]}$year $clock';
}

/// Short reminder text for cards, or null when the note has none.
String? reminderLabel(Note note) {
  final at = note.remindAt;
  if (at == null) return null;
  return note.reminderFired
      ? 'Reminder shown ${reminderTime(at)}'
      : 'Reminder ${reminderTime(at)}';
}

String noteTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${local.day} ${_months[local.month - 1]}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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
        return const Center(
          child: Icon(Icons.image_outlined, semanticLabel: 'Loading image'),
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
          semanticLabel: 'Attached note image',
          errorBuilder: (_, _, _) => _unavailableImage(),
        ),
      );
    },
  );

  Widget _unavailableImage() => Center(
    child: widget.thumbnail
        ? const Tooltip(
            message: 'Image unavailable. Open the note to retry or restore from a backup.',
            child: Icon(
              Icons.broken_image_outlined,
              semanticLabel: 'Image unavailable',
            ),
          )
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Image unavailable', textAlign: TextAlign.center),
                const Text(
                  'Retry loading or restore a copy from a complete backup.',
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
                  label: const Text('Retry image'),
                ),
              ],
            ),
          ),
  );
}
