/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.1.4';
const appBuild = '11';
const appName = 'BetterNotes';
String get appVersionLabel => '$appVersion+$appBuild';
