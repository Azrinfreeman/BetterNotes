import 'device_label_stub.dart' if (dart.library.io) 'device_label_io.dart';

/// A short, human-readable name for this device, stored with each backup so a
/// person can tell their machines apart when restoring.
String get localDeviceLabel => platformDeviceLabel();
