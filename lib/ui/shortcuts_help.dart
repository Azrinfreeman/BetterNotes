import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.settingsKeyboardShortcuts),
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shortcutsHelpLibraryAndNoteWindows,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(context.l10n.shortcutsHelpCtrlNNewNoteCtrl),
        SizedBox(height: 16),
        Text(
          context.l10n.shortcutsHelpInANote,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(context.l10n.shortcutsHelpCtrlWSaveAndClose),
        SizedBox(height: 16),
        Text(
          context.l10n.shortcutsHelpWhileEditingText,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(context.l10n.shortcutsHelpCtrlBIUT),
        SizedBox(height: 16),
        Text(context.l10n.shortcutsHelpSelectTextThenOpenText),
        SizedBox(height: 16),
        Text(context.l10n.shortcutsHelpUseTabAndShiftTab),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.reminderDone),
      ),
    ],
  ),
);
