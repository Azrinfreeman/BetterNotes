import 'package:sembast_web/sembast_web.dart';

Future<Database> openLocalDatabase() =>
    databaseFactoryWeb.openDatabase('better_notes.db');

const canQuarantineLocalDatabase = false;

Future<String?> quarantineLocalDatabase() async => null;
