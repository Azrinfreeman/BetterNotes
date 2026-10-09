import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown instead of a blank window when the local library cannot be opened.
class StartupErrorApp extends StatefulWidget {
  const StartupErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onReset,
    this.stack,
    this.canReset = true,
  });

  final Object error;
  final StackTrace? stack;
  final bool canReset;
  final Future<void> Function() onRetry;

  /// Sets the unreadable library aside and returns where it was moved.
  final Future<String?> Function() onReset;

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _busy = false;
  String? _failure;

  String get _details => '${widget.error}\n${widget.stack ?? ''}'.trim();

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _failure = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BetterNotes',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF795082),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        "BetterNotes couldn't open your notes",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nothing was changed or deleted. Try again first; if the '
                      'problem continues, start with an empty library and '
                      'restore from a backup.',
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '${widget.error}',
                      key: const ValueKey('startup-error'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_failure != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _failure!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : () => _run(widget.onRetry),
                          child: const Text('Try again'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _details)),
                          child: const Text('Copy details'),
                        ),
                        if (widget.canReset)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _confirmReset(context),
                            child: const Text('Start empty (keep a copy)'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start with an empty library?'),
        content: const Text(
          'The unreadable library file is renamed, not deleted, so it can '
          'still be recovered. Notes in your account sync back if you sign '
          'in; otherwise restore a backup from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start empty'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.onReset();
      await widget.onRetry();
    });
  }
}
