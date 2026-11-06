import 'dart:async';

import 'package:better_notes/data/google_drive_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

void main() {
  test('classifies failures into actionable kinds', () {
    expect(
      classifyDriveError(DriveNotConfiguredException()),
      DriveFailure.notConfigured,
    );
    expect(
      classifyDriveError(TimeoutException('sign-in')),
      DriveFailure.timedOut,
    );
    expect(
      classifyDriveError(
        oauth2.AuthorizationException('access_denied', 'denied', null),
      ),
      DriveFailure.denied,
    );
    expect(
      classifyDriveError(http.ClientException('offline')),
      DriveFailure.network,
    );
    expect(
      classifyDriveError(const FormatException('integrity')),
      DriveFailure.integrity,
    );
    expect(classifyDriveError(StateError('other')), DriveFailure.other);
    expect(classifyDriveError(ArgumentError('bad device')), DriveFailure.other);
  });

  test('the unconfigured error is still a StateError message', () {
    final error = DriveNotConfiguredException();
    expect(error, isA<StateError>());
    expect(error.message, contains('not configured'));
  });
}
