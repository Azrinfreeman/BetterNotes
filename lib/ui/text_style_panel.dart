import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../l10n/l10n.dart';

/// Expandable font size, color, heading, and list controls for the editor.
class TextStylePanel extends StatelessWidget {
  const TextStylePanel({
    super.key,
    required this.editor,
    required this.onChooseColor,
  });

  final quill.QuillController editor;
  final void Function(quill.Attribute attribute) onChooseColor;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .25,
    ),
    child: SingleChildScrollView(
      key: const ValueKey('text-style-panel'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.textStylePanelSelectTextToStyleIt),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              quill.QuillToolbarFontSizeButton(
                controller: editor,
                options: const quill.QuillToolbarFontSizeButtonOptions(
                  items: {
                    'Default': '0',
                    '12': '12',
                    '14': '14',
                    '16': '16',
                    '18': '18',
                    '24': '24',
                    '32': '32',
                    '48': '48',
                  },
                  defaultItemColor: null,
                ),
              ),
              IconButton(
                tooltip: context.l10n.textStylePanelTextColor,
                icon: const Icon(Icons.format_color_text),
                onPressed: () => onChooseColor(quill.Attribute.color),
              ),
              IconButton(
                tooltip: context.l10n.noteHighlightColor,
                icon: const Icon(Icons.format_color_fill),
                onPressed: () => onChooseColor(quill.Attribute.background),
              ),
              quill.QuillToolbarSelectHeaderStyleDropdownButton(
                controller: editor,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: editor,
                attribute: quill.Attribute.ol,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: editor,
                attribute: quill.Attribute.blockQuote,
              ),
              quill.QuillToolbarToggleStyleButton(
                controller: editor,
                attribute: quill.Attribute.inlineCode,
              ),
              quill.QuillToolbarClearFormatButton(controller: editor),
            ],
          ),
        ],
      ),
    ),
  );
}
