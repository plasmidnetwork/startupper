// Global app configuration flags.
// Use: flutter run --dart-define=BYPASS_VALIDATION=true
const bool kBypassValidation =
    bool.fromEnvironment('BYPASS_VALIDATION', defaultValue: false);
