# SpecEI Flutter Application

This directory contains the Flutter mobile application for SpecEI - Your AI Spectacle Companion.

---

## Application Overview

SpecEI is a cross-platform Flutter application that serves as the companion app for smart AI glasses. It provides authentication, memory management, and AI-powered interactions.

## Project Structure

```
specei_app/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── core/                        # Core utilities and configuration
│   │   ├── app_colors.dart          # Design system colors
│   │   ├── app_theme.dart           # Material theme configuration
│   │   ├── env_config.dart          # API keys (GITIGNORED)
│   │   └── env_config.example.dart  # Template for API configuration
│   ├── screens/                     # Application screens
│   │   ├── login_screen.dart        # User login with email/Google
│   │   ├── registration_screen.dart # Registration with OTP verification
│   │   ├── otp_verification_screen.dart  # 6-digit OTP entry
│   │   ├── forgot_password_screen.dart   # Password recovery
│   │   └── change_password_screen.dart   # Password update
│   ├── services/                    # Backend services
│   │   ├── auth_service.dart        # Firebase authentication
│   │   └── supabase_service.dart    # Database operations
│   └── widgets/                     # Reusable UI components
│       ├── custom_text_field.dart   # Styled input fields
│       ├── primary_button.dart      # Primary action buttons
│       ├── glass_panel.dart         # Glassmorphism container
│       └── social_auth_button.dart  # Google/Apple login buttons
├── android/                         # Android platform files
├── ios/                             # iOS platform files
├── windows/                         # Windows desktop files
├── web/                             # Web platform files
├── pubspec.yaml                     # Dependencies
└── supabase_migrations.sql          # Database schema
```

## Key Features

### Authentication System
- **Email/Password Login** - Traditional authentication
- **Google Sign-In** - OAuth integration
- **OTP Verification** - Email and phone verification during registration
- **Password Recovery** - Email-based password reset

### Registration Flow
1. User enters name and email (Gmail required)
2. Email verification via 6-digit OTP
3. Phone number entry (10-digit Indian format)
4. Phone verification via OTP
5. Password creation and confirmation
6. Account creation with Supabase storage

### Design System
- **Theme**: Dark mode with green accent (#4ADE80)
- **Fonts**: Space Grotesk (headings) + Inter (body)
- **Style**: Glassmorphism with subtle glow effects

## Environment Configuration

Create `lib/core/env_config.dart` from the template:

```dart
class EnvConfig {
  // Firebase Configuration
  static const String firebaseApiKey = 'YOUR_FIREBASE_API_KEY';
  static const String firebaseAppId = 'YOUR_FIREBASE_APP_ID';
  static const String firebaseMessagingSenderId = 'YOUR_SENDER_ID';
  static const String firebaseProjectId = 'YOUR_PROJECT_ID';
  static const String firebaseStorageBucket = 'YOUR_STORAGE_BUCKET';

  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

## Database Schema

Run `supabase_migrations.sql` in Supabase SQL Editor:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Running the App

```bash
# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d android

# Run on Chrome (web)
flutter run -d chrome

# Build release APK
flutter build apk --release
```

## Dependencies

Key packages used:
- `firebase_core` / `firebase_auth` - Firebase authentication
- `supabase_flutter` - Supabase database
- `google_sign_in` - OAuth for Google
- `google_fonts` - Typography

## Important Files

| File | Purpose |
|------|---------|
| `main.dart` | App initialization and Firebase/Supabase setup |
| `auth_service.dart` | All authentication logic |
| `supabase_service.dart` | Database CRUD operations |
| `registration_screen.dart` | Complete registration with OTP flow |
| `app_colors.dart` | Design system color palette |

## Security Notes

- ⚠️ Never commit `env_config.dart` to version control
- 🔒 API keys are stored separately from codebase
- 🛡️ Row Level Security (RLS) enabled on Supabase

---

For more information, see the main [README.md](../../README.md) in the project root.
