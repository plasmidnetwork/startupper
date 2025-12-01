// Global app configuration flags.
// Use: flutter run --dart-define=BYPASS_VALIDATION=true
const bool kBypassValidation =
    bool.fromEnvironment('BYPASS_VALIDATION', defaultValue: false);

// Supabase config (passed via dart-define for safety)
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
