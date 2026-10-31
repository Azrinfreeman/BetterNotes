import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_info.dart';

import 'package:window_manager/window_manager.dart';

import 'ui/review_notebook.dart';
import 'l10n/l10n.dart';
import 'data/app_log.dart';
import 'data/local_store.dart';
import 'desktop/windows_notes_stub.dart'
    if (dart.library.io) 'desktop/windows_notes_io.dart'
    as desktop;
import 'state/note_editor_store.dart';
import 'state/notes_controller.dart';
import 'ui/note_page.dart';
import 'ui/startup_error.dart';
import 'ui/notes_home.dart';
import 'ui/theme/notes_theme.dart';
import 'ui/theme/notes_chrome.dart';
export 'ui/theme/notes_theme.dart' show betterNotesTheme;
import 'desktop/window_chrome.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (arguments.contains('--ui-review')) {
    final controller = await createReviewNotebook();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.ensureInitialized();
      await windowManager.setTitle('BetterNotes ? UI review');
      await windowManager.setSize(const Size(1180, 820));
    }
    runApp(BetterNotesApp(controller: controller));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.show();
    }
    return;
  }
  await AppLog.init();
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.write(
      'ERROR',
      'Flutter: ${details.exceptionAsString()}',
      null,
      details.stack,
    );
    previousFlutterError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.write('ERROR', 'Unhandled', error, stack);
    return false;
  };
  final windows = await desktop.createDesktopCoordinator();
  if (windows.isNoteWindow) {
    // Every note window is its own engine; keep decoded images from each one
    // well below Flutter's 100 MB default so many open notes stay light.
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 24 << 20
      ..maximumSize = 50;
    final remote = await windows.createRemote();
    runApp(
      AnimatedBuilder(
        animation: remote,
        builder: (_, _) => NoteWindowApp(
          controller: remote,
          noteId: windows.noteId,
          closeRequests: windows.closeRequests,
          onClose: windows.closeSelf,
          onNewNote: windows.createAndOpenNote,
          onFindNotes: windows.focusSearch,
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(windows.notifyReady());
    });
    return;
  }
  AppLog.write('INFO', 'Started $appName $appVersionLabel');
  await _launchMain(windows, arguments);
}

Future<void> _launchMain(
  desktop.DesktopCoordinator windows,
  List<String> arguments,
) async {
  SupabaseClient? cloud;
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    cloud = Supabase.instance.client;
  }
  LocalStore? store;
  final NotesController controller;
  try {
    store = await LocalStore.open();
    controller = NotesController(store, cloud);
    await controller.load();
  } catch (error, stack) {
    AppLog.write('ERROR', 'Startup failed', error, stack);
    try {
      await store?.database.close();
    } catch (_) {
      // The handle may already be unusable; recovery only needs it released.
    }
    runApp(
      StartupErrorApp(
        error: error,
        stack: stack,
        canReset: LocalStore.canQuarantine,
        onReset: LocalStore.quarantine,
        onRetry: () => _launchMain(windows, arguments),
      ),
    );
    return;
  }
  if (arguments.contains('--reminders-due')) {
    // Started by the reminders scheduled task: leave quietly if nothing is due.
    await windows.quitIfNoRemindersDue(controller);
  }
  await windows.bindMain(controller);
  runApp(
    BetterNotesApp(
      controller: controller,
      openNoteWindow: windows.supportsNoteWindows ? windows.openNote : null,
      searchRequests: windows.searchRequests,
    ),
  );
  if (arguments.contains('--new-note') && windows.supportsNoteWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(windows.createAndOpenNote());
    });
  }
}

class BetterNotesApp extends StatelessWidget {
  const BetterNotesApp({
    super.key,
    required this.controller,
    this.openNoteWindow,
    this.searchRequests,
  });
  final NotesController controller;
  final Future<void> Function(String)? openNoteWindow;
  final ValueListenable<int>? searchRequests;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'BetterNotes',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => NotesEnvironment(
        reduceTransparency: controller.reduceTransparency,
        child: WindowChrome(
          customButtons: controller.customWindowButtons,
          showCaption: false,
          child: child!,
        ),
      ),
      themeMode: controller.themeMode,
      theme: betterNotesTheme(Brightness.light),
      darkTheme: betterNotesTheme(Brightness.dark),
      highContrastTheme: betterNotesTheme(Brightness.light, highContrast: true),
      highContrastDarkTheme: betterNotesTheme(
        Brightness.dark,
        highContrast: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotesHome(
        controller: controller,
        openNoteWindow: openNoteWindow,
        searchRequests: searchRequests,
      ),
    ),
  );
}

class NoteWindowApp extends StatelessWidget {
  const NoteWindowApp({
    super.key,
    required this.controller,
    required this.noteId,
    required this.onClose,
    this.closeRequests,
    this.onNewNote,
    this.onFindNotes,
  });

  final NoteEditorStore controller;
  final String? noteId;
  final Future<void> Function() onClose;
  final ValueListenable<int>? closeRequests;
  final Future<void> Function()? onNewNote;
  final Future<void> Function()? onFindNotes;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'BetterNotes',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => NotesEnvironment(
        reduceTransparency: controller.reduceTransparency,
        child: WindowChrome(
          customButtons: controller.customWindowButtons,
          showCaption: false,
          child: child!,
        ),
      ),
      themeMode: controller.themeMode,
      theme: betterNotesTheme(Brightness.light),
      darkTheme: betterNotesTheme(Brightness.dark),
      highContrastTheme: betterNotesTheme(Brightness.light, highContrast: true),
      highContrastDarkTheme: betterNotesTheme(
        Brightness.dark,
        highContrast: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: noteId == null
          ? const SizedBox.shrink()
          : NotePage(
              key: ValueKey(noteId),
              controller: controller,
              noteId: noteId!,
              onClose: onClose,
              closeRequests: closeRequests,
              onNewNote: onNewNote,
              onFindNotes: onFindNotes,
            ),
    ),
  );
}
