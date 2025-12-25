import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/env_config.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/otp_verification_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with configuration
  try {
    // For Windows/Web, provide explicit options
    // For Android/iOS, use google-services.json / GoogleService-Info.plist
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKey,
          appId: EnvConfig.firebaseAppId,
          messagingSenderId: EnvConfig.firebaseMessagingSenderId,
          projectId: EnvConfig.firebaseProjectId,
          storageBucket: EnvConfig.firebaseStorageBucket,
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('***** Firebase initialized successfully *****');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
    debugPrint('***** Supabase initialized successfully *****');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const SpecEIApp());
}

class SpecEIApp extends StatelessWidget {
  const SpecEIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpecEI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {'/': (context) => const LoginScreen()},
      onGenerateRoute: (settings) {
        if (settings.name == '/reset-password') {
          final identifier = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(identifier: identifier),
          );
        }
        if (settings.name == '/otp-verification') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              verificationType: args['type'],
              verificationTarget: args['target'],
              isPasswordReset: args['isPasswordReset'] ?? false,
            ),
          );
        }
        return null;
      },
    );
  }
}
