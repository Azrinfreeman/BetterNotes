import 'dart:io';

String platformDeviceLabel() {
  final host = Platform.localHostname.trim();
  if (host.isEmpty) return 'Windows device';
  return host.length > 80 ? host.substring(0, 80) : host;
}
