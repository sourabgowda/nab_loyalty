import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/router.dart';

void main() async {
  debugPrint(">>> APP STARTING <<<");
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase Initialized.");
  } catch (e) {
    debugPrint(
      "Firebase initialization failed (expected if config missing): $e",
    );
    // We continue so the app launches and shows UI, potentially catching error securely.
  }

  if (kDebugMode) {
    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
        forceRecaptchaFlow:
            true, // Try to force reCAPTCHA v2 flow if not disabled
      );
      // Actually, if we disable for testing, we can't use real numbers.
      // But we should probably try to set it to true to allow test numbers.
      // Also forceRecaptchaFlow: true might help if invisible is failing.
      // Let's just set appVerificationDisabledForTesting: true for now.

      debugPrint(
        "App verification disabled for testing. Use test credentials.",
      );
    } catch (e) {
      debugPrint("Failed to set auth settings: $e");
    }
  }

  debugPrint("Running App...");
  runApp(const ProviderScope(child: BunkLoyaltyApp()));
}

class BunkLoyaltyApp extends ConsumerWidget {
  const BunkLoyaltyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Bunk Loyalty',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
