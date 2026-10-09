import 'note.dart';

/// How many earlier versions of a note are kept.
const maxRevisionsPerNote = 20;

/// A saved earlier version of a note's content. Revisions stay on this device
/// (and in complete backups); they are never synced to the cloud.
class NoteRevision {
  NoteRevision({
    required this.id,
    required this.noteId,
    required this.createdAt,
    required this.title,
    required this.delta,
    required this.plainText,
    required this.colorIndex,
    required this.images,
    required this.tags,
  });

  final String id;
  final String noteId;
  final DateTime createdAt;
  final String title;
  final List<dynamic> delta;
  final String plainText;
  final int colorIndex;
  final List<String> images;
  final List<String> tags;

  /// Every image this version needs, including inline ones.
  Set<String> get imageIds => {...images, ...inlineImageIds(delta)};

  static NoteRevision capture(Note note, String id, DateTime at) =>
      NoteRevision(
        id: id,
        noteId: note.id,
        createdAt: at.toUtc(),
        title: note.title,
        delta: note.delta,
        plainText: note.plainText,
        colorIndex: note.colorIndex,
        images: note.images,
        tags: note.tags,
      );

  /// [light] drops the rich-text body; the history list only needs the text.
  Map<String, dynamic> toJson({bool light = false}) => {
    'id': id,
    'note_id': noteId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'title': title,
    if (!light) 'content': delta,
    'plain_text': plainText,
    'color_index': colorIndex,
    'images': images,
    'tags': tags,
  };

  factory NoteRevision.fromJson(Map<dynamic, dynamic> json) => NoteRevision(
    id: json['id'] as String,
    noteId: json['note_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    title: json['title'] as String? ?? '',
    delta: json['content'] as List<dynamic>? ?? const [],
    plainText: json['plain_text'] as String? ?? '',
    colorIndex: (json['color_index'] as num?)?.toInt() ?? 0,
    images: (json['images'] as List? ?? const []).cast<String>(),
    tags: normalizeTags((json['tags'] as List? ?? const []).cast<String>()),
  );
}
