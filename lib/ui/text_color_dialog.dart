import 'package:flutter/material.dart';

/// Null cancels, an empty string clears the attribute, otherwise returns #RRGGBB.
Future<String?> showTextColorDialog(
  BuildContext context, {
  required String title,
  String? initialColor,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextColorDialog(title: title, initialColor: initialColor),
);

class _TextColorDialog extends StatefulWidget {
  const _TextColorDialog({required this.title, this.initialColor});
  final String title;
  final String? initialColor;

  @override
  State<_TextColorDialog> createState() => _TextColorDialogState();
}

class _TextColorDialogState extends State<_TextColorDialog> {
  static const _colors = {
    'Plum': '#795082',
    'Red': '#C62828',
    'Orange': '#EF6C00',
    'Gold': '#F9A825',
    'Green': '#2E7D32',
    'Teal': '#00838F',
    'Blue': '#1565C0',
    'Pink': '#AD1457',
    'Black': '#000000',
    'White': '#FFFFFF',
  };
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hex;

  String? get _normalized {
    final value = _hex.text.trim().replaceFirst(RegExp(r'^#'), '');
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)
        ? '#${value.toUpperCase()}'
        : null;
  }

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController(text: widget.initialColor ?? '#795082');
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _apply() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _normalized);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 320,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in _colors.entries)
                  IconButton(
                    tooltip: entry.key,
                    isSelected: _normalized == entry.value,
                    onPressed: () => setState(() => _hex.text = entry.value),
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse('FF${entry.value.substring(1)}', radix: 16),
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: _normalized == entry.value
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: entry.key == 'White' || entry.key == 'Gold'
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hex,
              decoration: const InputDecoration(
                labelText: 'Hex color',
                hintText: '#795082',
              ),
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _apply(),
              validator: (_) => _normalized == null
                  ? 'Enter six hex digits, such as #795082.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: const Text('Reset color'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply')),
    ],
  );
}
