import 'package:flutter/material.dart';

Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Keyboard shortcuts'),
    scrollable: true,
    content: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Library and note windows',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('Ctrl+N — New note\nCtrl+F — Search library\nF1 — Shortcut help'),
        SizedBox(height: 16),
        Text('In a note', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'Ctrl+W — Save and close\nCtrl+D — Move to Trash\nCtrl+H — Find in this note\nEnter / Shift+Enter — Next / previous match\nEscape — Close find\nCtrl+Shift+V — Paste as plain text\nPaste a web address over selected text — Make a link',
        ),
        SizedBox(height: 16),
        Text(
          'While editing text',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Ctrl+B / I / U / T — Bold / italic / underline / strikethrough\nCtrl+Shift+L — Bulleted list\nCtrl+Z — Undo\nCtrl+Y — Redo\nCtrl+C / X / V / A — Copy / cut / paste / select all',
        ),
        SizedBox(height: 16),
        Text(
          'Select text, then open Text style options beside Add image for font size, text color, highlighting, headings, numbered lists, quotes, inline code, and clear formatting. With no selection, styles apply to what you type next.',
        ),
        SizedBox(height: 16),
        Text(
          'Use Tab and Shift+Tab to move between controls, and Enter or Space to activate them. Checklists, title, tags, favorites, and Archive are available from the toolbar or note menus. Closing keeps the note; deleting moves it to Trash.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  ),
);
