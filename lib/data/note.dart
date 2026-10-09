import 'package:uuid/uuid.dart';

const guestOwner = 'local';

// Image embeds reference the same cached assets as the legacy attachment list.
Set<String> inlineImageIds(List<dynamic> delta) => {
  for (final operation in delta)
    if (operation is Map && operation['insert'] is Map)
      if ((operation['insert'] as Map)['image'] case final String id) id,
};

List<dynamic> remapInlineImages(
  List<dynamic> delta,
  Map<String, String> imageIds,
) => [
  for (final operation in delta)
    if (operation is Map &&
        operation['insert'] is Map &&
        (operation['insert'] as Map)['image'] is String)
      <String, dynamic>{
        ...operation,
        'insert': <String, dynamic>{
          ...(operation['insert'] as Map),
          'image':
              imageIds[(operation['insert'] as Map)['image']] ??
              (operation['insert'] as Map)['image'],
        },
      }
    else
      operation,
];
const noteColors = <int>[
  0xFFFFE680, // lemon
  0xFFFFB88F, // peach
  0xFFE6C8F7, // lilac
  0xFFBCE8D4, // mint
  0xFFFFC7D8, // rose
  0xFFC9DCEE, // cloud
  0xFF9DDD83, // grass
  0xFF93DED8, // aqua
  0xFFAABFF2, // periwinkle
  0xFFFFAFA8, // coral
  0xFFE5D4BB, // sand
  0xFFE0E3E8, // silver
];
const noteColorNames = <String>[
  'Lemon',
  'Peach',
  'Lilac',
  'Mint',
  'Rose',
  'Cloud',
  'Grass',
  'Aqua',
  'Periwinkle',
  'Coral',
  'Sand',
  'Silver',
];

class InkStroke {
  const InkStroke({required this.color, required this.points});

  final int color;
  final List<List<double>> points;

  factory InkStroke.fromJson(Map<String, dynamic> json) => InkStroke(
    color: (json['color'] as num?)?.toInt() ?? 0xFF332B36,
    points: (json['points'] as List<dynamic>? ?? const [])
        .map(
          (point) => (point as List<dynamic>)
              .map((value) => (value as num).toDouble())
              .toList(),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {'color': color, 'points': points};
}

class Note {
  Note({
    required this.id,
    required this.ownerId,
    required this.delta,
    required this.plainText,
    required this.colorIndex,
    required this.images,
    required this.strokes,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.dirty,
    required this.deleted,
    this.deletedAt,
    this.title = '',
    this.favorite = false,
    this.tags = const [],
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final List<dynamic> delta;
  final String plainText;
  final int colorIndex;
  final List<String> images;
  final List<InkStroke> strokes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final bool dirty;
  final bool deleted;
  final DateTime? deletedAt;
  final String title;
  final bool favorite;
  final List<String> tags;
  final DateTime? archivedAt;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    for (final line in plainText.split('\n')) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return images.isNotEmpty
        ? 'Image note'
        : strokes.isNotEmpty
        ? 'Ink note'
        : 'Empty note';
  }

  String get textForExport {
    if (tasks.total == 0) return plainText;
    final output = StringBuffer();
    final line = StringBuffer();
    for (final op in delta) {
      if (op is! Map || op['insert'] is! String) continue;
      final parts = (op['insert'] as String).split('\n');
      for (var i = 0; i < parts.length; i++) {
        line.write(parts[i]);
        if (i == parts.length - 1) continue;
        final attributes = op['attributes'];
        final list = attributes is Map ? attributes['list'] : null;
        if (list == 'checked') output.write('[x] ');
        if (list == 'unchecked') output.write('[ ] ');
        output.writeln(line);
        line.clear();
      }
    }
    output.write(line);
    return output.toString().trimRight();
  }

  // Quill stores checklist state on paragraph-ending newlines.
  ({int done, int total}) get tasks {
    var done = 0;
    var total = 0;
    for (final op in delta) {
      if (op is! Map || op['insert'] is! String || op['attributes'] is! Map) {
        continue;
      }
      final list = (op['attributes'] as Map)['list'];
      if (list != 'checked' && list != 'unchecked') continue;
      final count = '\n'.allMatches(op['insert'] as String).length;
      total += count;
      if (list == 'checked') done += count;
    }
    return (done: done, total: total);
  }

  static Note fresh(String ownerId) {
    final now = DateTime.now().toUtc();
    return Note(
      id: const Uuid().v4(),
      ownerId: ownerId,
      delta: const [
        {'insert': '\n'},
      ],
      plainText: '',
      colorIndex: 0,
      images: const [],
      strokes: const [],
      createdAt: now,
      updatedAt: now,
      revision: 0,
      dirty: true,
      deleted: false,
    );
  }

  Note copyWith({
    String? id,
    String? ownerId,
    List<dynamic>? delta,
    String? plainText,
    int? colorIndex,
    List<String>? images,
    List<InkStroke>? strokes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? revision,
    bool? dirty,
    bool? deleted,
    DateTime? deletedAt,
    String? title,
    bool? favorite,
    List<String>? tags,
    DateTime? archivedAt,
    bool clearArchive = false,
  }) => Note(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    delta: delta ?? this.delta,
    plainText: plainText ?? this.plainText,
    colorIndex: colorIndex ?? this.colorIndex,
    images: images ?? this.images,
    strokes: strokes ?? this.strokes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    deletedAt: (deleted ?? this.deleted) ? deletedAt ?? this.deletedAt : null,
    title: title ?? this.title,
    favorite: favorite ?? this.favorite,
    tags: tags == null ? this.tags : normalizeTags(tags),
    archivedAt: clearArchive ? null : archivedAt ?? this.archivedAt,
  );

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    delta:
        json['content'] as List<dynamic>? ??
        const [
          {'insert': '\n'},
        ],
    plainText: json['plain_text'] as String? ?? '',
    colorIndex: (json['color_index'] as num?)?.toInt() ?? 0,
    images: (json['images'] as List<dynamic>? ?? const [])
        .map((value) => value as String)
        .toList(),
    strokes: (json['strokes'] as List<dynamic>? ?? const [])
        .map((value) => InkStroke.fromJson(Map<String, dynamic>.from(value)))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    dirty: json['dirty'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
    deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? ''),
    title: json['title'] as String? ?? '',
    favorite: json['favorite'] as bool? ?? false,
    tags: normalizeTags(
      (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
    ),
    archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'content': delta,
    'plain_text': plainText,
    'color_index': colorIndex,
    'images': images,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'dirty': dirty,
    'deleted': deleted,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    'title': title,
    'favorite': favorite,
    'tags': tags,
    'archived_at': archivedAt?.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toRemoteJson() {
    final json = toJson();
    json.remove('dirty');
    json.remove('deleted_at'); // Local metadata; the cloud schema is unchanged.
    for (final key in ['title', 'favorite', 'tags', 'archived_at']) {
      json.remove(key);
    }
    return json;
  }
}

List<String> normalizeTags(Iterable<String> tags) =>
    (tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort());
