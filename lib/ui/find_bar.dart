import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Find-in-note strip; match state and navigation stay with the editor.
class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.matches,
    required this.index,
    required this.onQueryChanged,
    required this.onStep,
    required this.onClose,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final int matches;
  final int index;
  final VoidCallback onQueryChanged;
  final void Function(int direction) onStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): () =>
                    onStep(-1),
              },
              child: TextField(
                key: const ValueKey('find-in-note'),
                controller: textController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Find in this note (Ctrl+H)',
                  border: InputBorder.none,
                ),
                onChanged: (_) => onQueryChanged(),
                onSubmitted: (_) {
                  onStep(1);
                  focusNode.requestFocus();
                },
              ),
            ),
          ),
          Text(
            matches == 0 ? '0/0' : '${index + 1}/$matches',
            semanticsLabel: '$matches matches',
          ),
          IconButton(
            tooltip: 'Previous match',
            onPressed: matches == 0 ? null : () => onStep(-1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: matches == 0 ? null : () => onStep(1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: 'Close find',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
