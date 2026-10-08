import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'desktop_callback_web.dart'
    if (dart.library.io) 'desktop_callback_io.dart';

Future<void> signInWithGoogle(SupabaseClient client) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final callback = await DesktopCallback.start();
    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: DesktopCallback.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('Could not open the browser.');
      await client.auth.exchangeCodeForSession(await callback.waitForCode());
    } finally {
      await callback.close();
    }
    return;
  }

  await client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb ? null : 'dev.betternotes://login-callback/',
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
}
