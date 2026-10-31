import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'notes_theme.dart';

class NotesEnvironment extends StatefulWidget {
  const NotesEnvironment({
    super.key,
    required this.reduceTransparency,
    required this.child,
  });
  final bool reduceTransparency;
  final Widget child;
  @override
  State<NotesEnvironment> createState() => _NotesEnvironmentState();
}

class _NotesEnvironmentState extends State<NotesEnvironment> {
  bool _keyboard = true;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (_keyboard) setState(() => _keyboard = false);
    },
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && !_keyboard) {
          setState(() => _keyboard = true);
        }
        return KeyEventResult.ignored;
      },
      child: NotesAppearance(
        reduceTransparency: widget.reduceTransparency,
        keyboardNavigation: _keyboard,
        child: widget.child,
      ),
    ),
  );
}

/// Optional in-app frost, clipped to a genuinely overlapping chrome region.
class NotesChrome extends StatelessWidget {
  const NotesChrome({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.surface;
    final solid =
        NotesAppearance.of(context)?.reduceTransparency != false ||
        MediaQuery.highContrastOf(context);
    final content = ColoredBox(
      color: solid ? base : base.withValues(alpha: 0.88),
      child: child,
    );
    return ClipRect(
      child: solid
          ? content
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: content,
            ),
    );
  }
}

/// Retargets a panel from its current presentation value and velocity.
class NotesSpringPanel extends StatefulWidget {
  const NotesSpringPanel({super.key, required this.open, required this.child});
  final bool open;
  final Widget child;
  @override
  State<NotesSpringPanel> createState() => _NotesSpringPanelState();
}

class _NotesSpringPanelState extends State<NotesSpringPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  void _retarget() {
    final target = widget.open ? 1.0 : 0.0;
    final immediate =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        NotesAppearance.of(context)?.keyboardNavigation != false;
    if (immediate) {
      _controller.value = target;
      return;
    }
    const response = 0.30;
    final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
    final velocity = _controller.velocity;
    _controller.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: stiffness,
          damping: 2 * math.sqrt(stiffness),
        ),
        _controller.value,
        target,
        velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(NotesSpringPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) _retarget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retarget();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Align(
      alignment: Alignment.topCenter,
      heightFactor: _controller.value.clamp(0.0, 1.0),
      child: ClipRect(
        child: IgnorePointer(
          ignoring: !widget.open,
          child: ExcludeFocus(
            excluding: !widget.open,
            child: ExcludeSemantics(
              excluding: !widget.open,
              child: Opacity(
                opacity: _controller.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
