/// Public Google OAuth configuration supplied at build time.
///
/// The client ID and secret for an installed ("Desktop app") client are not
/// confidential; Google documents the secret as non-confidential for installed
/// apps. Access and refresh tokens are never stored here.
const googleDriveDesktopClientId = String.fromEnvironment(
  'GOOGLE_DRIVE_DESKTOP_CLIENT_ID',
);

const googleDriveDesktopClientSecret = String.fromEnvironment(
  'GOOGLE_DRIVE_DESKTOP_CLIENT_SECRET',
);

/// `openid email` only names the signed-in account for display. Drive access
/// stays limited to the hidden app data folder.
const googleDriveScopes = <String>[
  'openid',
  'email',
  'https://www.googleapis.com/auth/drive.appdata',
];
