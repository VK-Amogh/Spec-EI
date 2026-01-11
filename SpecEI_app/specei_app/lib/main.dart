import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'core/env_config.dart';
import 'core/logger.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/server_connectivity_service.dart';
import 'services/security_service.dart'; // Security Core

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
      // Set persistence for web - keeps user logged in until explicit logout
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } else {
      await Firebase.initializeApp();
    }
    AppLogger.info('Firebase initialized');
  } catch (e) {
    AppLogger.error('Firebase initialization failed', e);
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
    AppLogger.info('Supabase initialized');
  } catch (e) {
    AppLogger.error('Supabase initialization failed', e);
  }

  // Initialize Notification Service (for reminders)
  try {
    await NotificationService().initialize();
    AppLogger.info('Notification service initialized');
  } catch (e) {
    AppLogger.error('Notification initialization failed', e);
  }

  // Initialize Security Service & App Hardening
  try {
    final security = SecurityService();
    await security.initialize();
    await security
        .enableScreenSecurity(); // Prevent screenshots of sensitive content
    final isRooted = await security.isDeviceRooted();
    if (isRooted) {
      AppLogger.warning('🚨 CAUTION: Running on Rooted/Jailbroken Device');
    }
  } catch (e) {
    AppLogger.error('Security Service initialization failed', e);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider(
          create: (_) => ServerConnectivityService()..checkConnections(),
        ),
      ],
      child: const SpecEIApp(),
    ),
  );
}

class SpecEIApp extends StatelessWidget {
  const SpecEIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LocaleService>(
      builder: (context, themeService, localeService, child) {
        return MaterialApp(
          title: 'SpecEI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          // Localization support
          locale: localeService.locale,
          supportedLocales: LocaleService.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Auth-aware home - automatically redirect to MainScreen when logged in
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Auth state logging (masked in production)
              AppLogger.debug(
                'Auth: ${snapshot.connectionState}, user=${AppLogger.maskEmail(snapshot.data?.email)}',
              );

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const MainScreen();
              }
              return const LoginScreen();
            },
          ),
          // Named routes for OTP verification and password reset flows
          onGenerateRoute: (settings) {
            if (settings.name == '/reset-password') {
              final identifier = settings.arguments as String? ?? '';
              return MaterialPageRoute(
                builder: (context) =>
                    ResetPasswordScreen(identifier: identifier),
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
      },
    );
  }
}
