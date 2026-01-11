// SpecEI Environment Configuration
// Copy this file to env_config.dart and fill in your API keys
// DO NOT commit env_config.dart to version control!

class EnvConfig {
  // Firebase Configuration
  static const String firebaseApiKey = 'YOUR_FIREBASE_API_KEY';
  static const String firebaseAppId = 'YOUR_FIREBASE_APP_ID';
  static const String firebaseMessagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const String firebaseProjectId = 'YOUR_PROJECT_ID';
  static const String firebaseStorageBucket = 'YOUR_STORAGE_BUCKET';

  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Groq AI Configuration (get free key at console.groq.com/keys)
  static const String groqApiKey = 'YOUR_GROQ_API_KEY';

  // Local Whisper Server (run AI_Backend/start_server.ps1)
  static const String localWhisperUrl = 'http://localhost:8000/transcribe';
}
