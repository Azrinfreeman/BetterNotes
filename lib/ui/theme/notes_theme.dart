import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/note.dart';

/// App chrome colors. Document colors and saved color indexes are independent.
@immutable
class NotesColors extends ThemeExtension<NotesColors> {
  const NotesColors({
    required this.sidebar,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
  });

  final Color sidebar;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;

  static NotesColors of(BuildContext context) =>
      Theme.of(context).extension<NotesColors>() ??
      palette(Theme.of(context).brightness);

  static NotesColors palette(Brightness brightness) =>
      brightness == Brightness.dark
      ? const NotesColors(
          sidebar: Color(0xFF1C1C1E),
          success: Color(0xFF6ED69C),
          successSurface: Color(0xFF193426),
          warning: Color(0xFFF2C066),
          warningSurface: Color(0xFF382C17),
        )
      : const NotesColors(
          sidebar: Color(0xFFEEEEF1),
          success: Color(0xFF1F6F43),
          successSurface: Color(0xFFEAF6EE),
          warning: Color(0xFF8A5700),
          warningSurface: Color(0xFFFFF4DB),
        );

  @override
  NotesColors copyWith({
    Color? sidebar,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
  }) => NotesColors(
    sidebar: sidebar ?? this.sidebar,
    success: success ?? this.success,
    successSurface: successSurface ?? this.successSurface,
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
  );

  @override
  NotesColors lerp(NotesColors? other, double t) => other == null
      ? this
      : NotesColors(
          sidebar: Color.lerp(sidebar, other.sidebar, t)!,
          success: Color.lerp(success, other.success, t)!,
          successSurface: Color.lerp(successSurface, other.successSurface, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
        );
}

Color noteSurface(BuildContext context, int index, {bool chrome = false}) {
  final scheme = Theme.of(context).colorScheme;
  if (MediaQuery.highContrastOf(context)) return scheme.surface;
  final color = Color(noteColors[index % noteColors.length]);
  return Color.alphaBlend(
    color.withValues(alpha: chrome ? 0.24 : 0.12),
    scheme.surface,
  );
}

final _themes = <(Brightness, bool), ThemeData>{};

ThemeData betterNotesTheme(
  Brightness brightness, {
  bool highContrast = false,
}) => _themes.putIfAbsent((brightness, highContrast), () {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
  final canvas = dark ? const Color(0xFF141416) : const Color(0xFFF5F5F7);
  final raised = dark ? const Color(0xFF2C2C2E) : Colors.white;
  final text = dark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
  final secondary = dark ? const Color(0xFFADB0B8) : const Color(0xFF5C6068);
  final primary = dark ? const Color(0xFF66A8FF) : const Color(0xFF005FCC);
  final selected = dark ? const Color(0xFF203750) : const Color(0xFFE8F0FC);
  final separator = dark ? const Color(0xFF45474F) : const Color(0xFFE5E5EA);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        contrastLevel: highContrast ? 1 : 0,
      ).copyWith(
        primary: primary,
        onPrimary: dark ? const Color(0xFF121214) : Colors.white,
        primaryContainer: selected,
        onPrimaryContainer: text,
        secondary: primary,
        onSecondary: dark ? const Color(0xFF121214) : Colors.white,
        secondaryContainer: selected,
        onSecondaryContainer: text,
        surface: surface,
        surfaceDim: canvas,
        surfaceBright: raised,
        surfaceContainerLowest: canvas,
        surfaceContainerLow: canvas,
        surfaceContainer: surface,
        surfaceContainerHigh: raised,
        surfaceContainerHighest: dark
            ? const Color(0xFF38383C)
            : const Color(0xFFEEEEF1),
        onSurface: text,
        onSurfaceVariant: highContrast ? text : secondary,
        outline: highContrast ? text : const Color(0xFF858B96),
        outlineVariant: highContrast ? text : separator,
        error: dark ? const Color(0xFFFF8A93) : const Color(0xFFB42332),
        onError: dark ? const Color(0xFF121214) : Colors.white,
        errorContainer: dark
            ? const Color(0xFF3D2025)
            : const Color(0xFFFDEDEF),
        onErrorContainer: dark
            ? const Color(0xFFFF8A93)
            : const Color(0xFFB42332),
      );
  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? 'Segoe UI'
        : null,
  );
  final textTheme = base.textTheme.copyWith(
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: text,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.27,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: text,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      height: 1.33,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: text),
    bodyMedium: TextStyle(fontSize: 14, height: 1.43, color: text),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: secondary),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w500,
      color: text,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w500,
      color: secondary,
    ),
    labelSmall: TextStyle(fontSize: 12, height: 1.33, color: secondary),
  );
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    textTheme: textTheme,
    extensions: [NotesColors.palette(brightness)],
    focusColor: primary.withValues(alpha: 0.18),
    hoverColor: primary.withValues(alpha: 0.06),
    splashFactory: NoSplash.splashFactory,
    dividerColor: scheme.outlineVariant,
    iconTheme: IconThemeData(size: 20, color: secondary),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: canvas,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleMedium,
      toolbarHeight: 56,
      iconTheme: IconThemeData(size: 20, color: secondary),
      actionsIconTheme: IconThemeData(size: 20, color: secondary),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highContrast ? BorderSide(color: text) : BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: textTheme.labelLarge,
        animationDuration: const Duration(milliseconds: 120),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(44, 44),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(44, 44),
        iconSize: 20,
        foregroundColor: secondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      hintStyle: TextStyle(color: secondary, fontSize: 14),
      border: inputBorder(scheme.outline),
      enabledBorder: inputBorder(scheme.outline),
      focusedBorder: inputBorder(primary, 2),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 2),
    ),
    chipTheme: ChipThemeData(
      shape: controlShape,
      side: BorderSide.none,
      backgroundColor: raised,
      selectedColor: selected,
      labelStyle: textTheme.labelMedium?.copyWith(color: text),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: secondary,
      textColor: text,
      selectedColor: primary,
      selectedTileColor: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: textTheme.bodyMedium,
      subtitleTextStyle: textTheme.bodySmall,
      shape: controlShape,
      minLeadingWidth: 20,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 24,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: raised,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: textTheme.bodyMedium,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(raised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: true,
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: NotesPageTransitions(),
      },
    ),
  );
});

/// Keyboard workflows remain immediate; pointer routes retain spatial continuity.
class NotesPageTransitions extends PageTransitionsBuilder {
  const NotesPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        NotesAppearance.of(context)?.keyboardNavigation != false) {
      return child;
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}

class NotesAppearance extends InheritedWidget {
  const NotesAppearance({
    super.key,
    required this.reduceTransparency,
    required this.keyboardNavigation,
    required super.child,
  });
  final bool reduceTransparency;
  final bool keyboardNavigation;
  static NotesAppearance? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotesAppearance>();
  @override
  bool updateShouldNotify(NotesAppearance oldWidget) =>
      reduceTransparency != oldWidget.reduceTransparency ||
      keyboardNavigation != oldWidget.keyboardNavigation;
}
