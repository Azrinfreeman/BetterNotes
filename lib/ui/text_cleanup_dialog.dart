import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

import '../data/text_cleanup.dart';
import '../l10n/l10n.dart';

class TextCleanupDialog extends StatefulWidget {
  const TextCleanupDialog({
    super.key,
    required this.snapshot,
    required this.selection,
    required this.liveController,
    required this.changes,
    required this.isCurrent,
    required this.embedBuilders,
  });
  final Delta snapshot;
  final TextSelection selection;
  final quill.QuillController liveController;
  final Listenable changes;
  final bool Function() isCurrent;
  final List<quill.EmbedBuilder> embedBuilders;
  @override
  State<TextCleanupDialog> createState() => _TextCleanupDialogState();
}

class _TextCleanupDialogState extends State<TextCleanupDialog> {
  bool _trailing = true, _blank = true, _repeated = false, _stale = false;
  late TextCleanupResult _result;
  late quill.QuillController _preview;
  final _focus = FocusNode();
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _compute();
    widget.changes.addListener(_check);
    widget.liveController.addListener(_check);
    _stale = !widget.isCurrent();
  }

  void _check() {
    if (!_stale && !widget.isCurrent()) setState(() => _stale = true);
  }

  void _compute() {
    _result = planTextCleanup(
      widget.snapshot,
      widget.selection,
      TextCleanupOptions(
        trailingSpaces: _trailing,
        blankLines: _blank,
        repeatedSpaces: _repeated,
      ),
    );
    _preview = quill.QuillController(
      document: quill.Document.fromDelta(_result.preview),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  void _option(VoidCallback update) {
    final old = _preview;
    setState(() {
      update();
      _compute();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    widget.changes.removeListener(_check);
    widget.liveController.removeListener(_check);
    _preview.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(12),
    title: Text(
      widget.selection.isCollapsed
          ? context.l10n.cleanupNote
          : context.l10n.cleanupSelection,
    ),
    content: SizedBox(
      width: 600,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.cleanupTrailing),
                  value: _trailing,
                  onChanged: (v) => _option(() => _trailing = v!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.cleanupBlank),
                  value: _blank,
                  onChanged: (v) => _option(() => _blank = v!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.cleanupRepeated),
                  value: _repeated,
                  onChanged: (v) => _option(() => _repeated = v!),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _stale
                        ? context.l10n.cleanupStale
                        : _result.hasChanges
                        ? context.l10n.cleanupCounts(
                            _result.spacesRemoved,
                            _result.blankLinesRemoved,
                          )
                        : context.l10n.cleanupNone,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: quill.QuillEditor(
                    key: ObjectKey(_preview),
                    controller: _preview,
                    focusNode: _focus,
                    scrollController: _scroll,
                    config: quill.QuillEditorConfig(
                      padding: const EdgeInsets.all(8),
                      embedBuilders: widget.embedBuilders,
                      showCursor: false,
                      enableInteractiveSelection: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cleanupCancel),
      ),
      FilledButton(
        onPressed: !_stale && _result.hasChanges
            ? () {
                _check();
                if (!_stale) Navigator.pop(context, _result);
              }
            : null,
        child: Text(context.l10n.cleanupApply),
      ),
    ],
  );
}
