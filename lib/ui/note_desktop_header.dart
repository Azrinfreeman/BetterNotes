import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/l10n.dart';
import '../data/note.dart';

/// Auto-hiding colored header for Windows note windows. Visibility and hover
/// state stay with the page; this widget only draws and reports interactions.
class NoteDesktopHeader extends StatelessWidget implements PreferredSizeWidget {
  const NoteDesktopHeader({
    super.key,
    required this.note,
    required this.visible,
    required this.alwaysOnTop,
    required this.menuItems,
    required this.onHover,
    required this.onFocusChange,
    required this.onNewNote,
    required this.onChangeColor,
    required this.onToggleAlwaysOnTop,
    required this.onMenuOpened,
    required this.onMenuCanceled,
    required this.onMenuSelected,
    required this.onClose,
  });

  final Note note;
  final bool visible;
  final bool alwaysOnTop;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback? onNewNote;
  final VoidCallback onChangeColor;
  final VoidCallback onToggleAlwaysOnTop;
  final VoidCallback onMenuOpened;
  final VoidCallback onMenuCanceled;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) => MouseRegion(
    key: const ValueKey('note-header-hover'),
    onEnter: (_) => onHover(true),
    onExit: (_) => onHover(false),
    child: Focus(
      canRequestFocus: false,
      onFocusChange: onFocusChange,
      child: AnimatedOpacity(
        key: const ValueKey('note-header-opacity'),
        opacity: visible ? 1 : 0,
        alwaysIncludeSemantics: true,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: Color(noteColors[note.colorIndex % noteColors.length]),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF2E2631),
                ),
              ),
              child: IconTheme(
                data: const IconThemeData(color: Color(0xFF2E2631)),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (onNewNote != null)
                        IconButton(
                          tooltip: context.l10n.noteDesktopHeaderNewNote,
                          onPressed: onNewNote,
                          icon: const Icon(Icons.add),
                        ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) =>
                              unawaited(windowManager.startDragging()),
                          onDoubleTap: () async {
                            if (await windowManager.isMaximized()) {
                              await windowManager.unmaximize();
                            } else {
                              await windowManager.maximize();
                            }
                          },
                          child: Semantics(
                            label: note.displayTitle,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.noteDesktopHeaderChangeColor,
                        onPressed: onChangeColor,
                        icon: const Icon(Icons.palette_outlined),
                      ),
                      IconButton(
                        tooltip: alwaysOnTop
                            ? context.l10n.noteDesktopHeaderTurnOffAlwaysOnTop
                            : context.l10n.noteDesktopHeaderAlwaysOnTop,
                        isSelected: alwaysOnTop,
                        onPressed: onToggleAlwaysOnTop,
                        icon: const Icon(Icons.push_pin_outlined),
                        selectedIcon: const Icon(Icons.push_pin),
                      ),
                      PopupMenuButton<String>(
                        tooltip: context.l10n.noteDesktopHeaderMoreActions,
                        onOpened: onMenuOpened,
                        onCanceled: onMenuCanceled,
                        onSelected: onMenuSelected,
                        itemBuilder: (_) => menuItems,
                      ),
                      IconButton(
                        tooltip: context.l10n.noteDesktopHeaderCloseNote,
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
