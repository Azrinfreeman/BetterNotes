import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../l10n/l10n.dart';
import '../state/note_editor_store.dart';
import 'notes_home.dart';

class NoteImageEmbedBuilder extends quill.EmbedBuilder {
  const NoteImageEmbedBuilder({
    required this.store,
    required this.noteId,
    required this.onRemove,
  });

  final NoteEditorStore store;
  final String noteId;
  final void Function(int)? onRemove;

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) =>
      NoteImageCard(
        controller: store,
        noteId: noteId,
        imageId: embedContext.node.value.data as String,
        inline: true,
        onRemove: onRemove == null
            ? null
            : () => onRemove!(embedContext.node.documentOffset),
      );
}

class NoteImageCard extends StatelessWidget {
  const NoteImageCard({
    super.key,
    required this.controller,
    required this.noteId,
    required this.imageId,
    required this.onRemove,
    this.inline = false,
  });

  final NoteEditorStore controller;
  final String noteId;
  final String imageId;
  final VoidCallback? onRemove;
  final bool inline;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('${inline ? 'inline' : 'above'}-image-$imageId'),
    padding: const EdgeInsets.only(bottom: 12),
    child: Stack(
      children: [
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.9,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: NoteImage(
                  controller: controller,
                  noteId: noteId,
                  imageId: imageId,
                ),
              ),
            ),
          ),
          child: inline
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 64,
                    maxHeight: 300,
                  ),
                  child: NoteImage(
                    controller: controller,
                    noteId: noteId,
                    imageId: imageId,
                  ),
                )
              : SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: NoteImage(
                    controller: controller,
                    noteId: noteId,
                    imageId: imageId,
                  ),
                ),
        ),
        if (onRemove != null)
          Positioned(
            right: 5,
            top: 5,
            child: IconButton.filledTonal(
              tooltip: context.l10n.noteImageEmbedRemoveImage,
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
      ],
    ),
  );
}
