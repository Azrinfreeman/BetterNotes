import 'dart:convert';
import 'dart:io';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/l10n/app_localizations_en.dart';
import 'package:better_notes/l10n/l10n.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/about_page.dart';
import 'package:better_notes/ui/note_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sembast/sembast_memory.dart';

class _Shouty extends AppLocalizationsEn {
  @override
  String get aboutTitle => 'ABOUT (TEST LOCALE)';
}

class _ShoutyDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _ShoutyDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) async => _Shouty();
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget text comes from the string table, not literals', () {
    // New UI text must go through context.l10n so it can be translated.
    final literal = RegExp(
      r'''(?:Text|SelectableText)\(\s*(?:'[^']*[A-Za-z]{2}[^']*'|"[^"]*[A-Za-z]{2}[^"]*")|(?:tooltip|hintText|labelText|helperText|semanticLabel|placeholder):\s*(?:'[^']*[A-Za-z]{2}|"[^"]*[A-Za-z]{2})''',
    );
    final offenders = <String>[];
    for (final entity in Directory('lib/ui').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('l10n') || line.trimLeft().startsWith('//')) continue;
        // Interpolation-only text such as Text('$error') has no words.
        if (literal.hasMatch(line.replaceAll(RegExp(r'\$\{?\w+\}?'), ''))) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the English template is valid and every message is generated', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = arb.keys.where((k) => !k.toString().startsWith('@'));
    expect(keys.length, greaterThan(250));
    final generated = File('lib/l10n/app_localizations.dart')
        .readAsStringSync();
    for (final key in keys) {
      if (key == '@@locale') continue;
      expect(
        generated,
        contains(' get $key;').or(contains(' $key(')),
        reason: '$key',
      );
    }
  });

  testWidgets('another locale replaces the UI strings', (tester) async {
    final (controller, db) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase('l10n-ui');
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          return (controller, db);
        }) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          _ShoutyDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: AboutPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABOUT (TEST LOCALE)'), findsOneWidget);
    expect(find.text('About BetterNotes'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  test('dates follow the locale', () async {
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
    final old = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = old);
    final date = DateTime(2020, 10, 12, 21, 5);
    Intl.defaultLocale = 'en_US';
    expect(noteTime(date), 'Oct 12');
    expect(reminderTime(date), contains('Oct 12, 2020'));
    Intl.defaultLocale = 'en_GB';
    expect(noteTime(date), '12 Oct');
    expect(reminderTime(date), contains('12 Oct 2020'));
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
