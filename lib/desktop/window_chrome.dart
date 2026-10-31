import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/l10n.dart';

/// Applies the native frame style and shares controls with route app bars.
class WindowChrome extends StatefulWidget {
  const WindowChrome({
    super.key,
    required this.customButtons,
    required this.child,
    this.showCaption = true,
  });

  final bool customButtons;
  final Widget child;
  final bool showCaption;

  @override
  State<WindowChrome> createState() => _WindowChromeState();
}

class _WindowChromeState extends State<WindowChrome> with WindowListener {
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool _customButtons = false;
  bool _maximized = false;
  Future<void> _pending = Future<void>.value();
  late final OverlayEntry _content;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    _content = OverlayEntry(builder: _buildContent);
    if (_supported) {
      windowManager.addListener(this);
      _updateStyle();
    }
  }

  @override
  void didUpdateWidget(WindowChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_supported && oldWidget.customButtons != widget.customButtons) {
      _updateStyle();
    }
  }

  void _updateStyle() {
    final custom = widget.customButtons;
    // Keep rapid setting changes in order, including native frame updates.
    _pending = _pending.then((_) async {
      if (!mounted) return;
      try {
        await windowManager.ensureInitialized();
        await windowManager.setTitleBarStyle(
          custom ? TitleBarStyle.hidden : TitleBarStyle.normal,
        );
        final maximized = await windowManager.isMaximized();
        if (mounted) {
          setState(() {
            _customButtons = custom;
            _maximized = maximized;
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.windowChromeCouldNotChangeWindowButtons('$error'),
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  @override
  void dispose() {
    if (_supported) windowManager.removeListener(this);
    if (_hasOverlay) _content.remove();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return widget.child;
    _hasOverlay = true;
    _content.markNeedsBuild();
    // Caption tooltips need an overlay above both the frame and navigator.
    return Overlay(initialEntries: [_content]);
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_customButtons && widget.showCaption)
          Material(
            color: colors.surfaceContainer,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) =>
                          unawaited(windowManager.startDragging()),
                      onDoubleTap: _toggleMaximize,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.l10n.windowChromeBetternotes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.windowChromeMinimize,
                    onPressed: windowManager.minimize,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: _maximized ? 'Restore' : 'Maximize',
                    onPressed: _toggleMaximize,
                    icon: Icon(
                      _maximized ? Icons.filter_none : Icons.crop_square,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton.filledTonal(
                      tooltip: context.l10n.windowChromeCloseWindow,
                      style: IconButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        backgroundColor: Colors.transparent,
                      ),
                      // The coordinator intercepts close to save notes and bounds.
                      onPressed: windowManager.close,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _WindowControls(
            enabled: _customButtons,
            maximized: _maximized,
            toggleMaximize: _toggleMaximize,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _WindowControls extends InheritedWidget {
  const _WindowControls({
    required this.enabled,
    required this.maximized,
    required this.toggleMaximize,
    required super.child,
  });

  final bool enabled;
  final bool maximized;
  final Future<void> Function() toggleMaximize;

  static _WindowControls? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WindowControls>();

  @override
  bool updateShouldNotify(_WindowControls oldWidget) =>
      enabled != oldWidget.enabled || maximized != oldWidget.maximized;
}

/// Makes the app bar title and its empty space draggable with custom controls.
class WindowTitle extends StatelessWidget {
  const WindowTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controls = _WindowControls.of(context);
    if (controls == null || !controls.enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(windowManager.startDragging()),
      onDoubleTap: controls.toggleMaximize,
      child: SizedBox(
        width: double.infinity,
        height: kToolbarHeight,
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

/// Themed window actions shown only after the native caption has been hidden.
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final controls = _WindowControls.of(context);
    if (controls == null || !controls.enabled) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.windowChromeMinimize,
          onPressed: windowManager.minimize,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: controls.maximized ? 'Restore' : 'Maximize',
          onPressed: controls.toggleMaximize,
          icon: Icon(
            controls.maximized ? Icons.filter_none : Icons.crop_square,
          ),
        ),
        IconButton.filledTonal(
          tooltip: context.l10n.windowChromeCloseWindow,
          style: IconButton.styleFrom(
            foregroundColor: colors.onSurface,
            backgroundColor: Colors.transparent,
          ),
          // The coordinator intercepts close to save notes and bounds.
          onPressed: windowManager.close,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
