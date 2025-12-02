import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'auth/auth_screen.dart';
import 'feed/feed_screen.dart';
import 'onboarding/common_onboarding_screen.dart';
import 'onboarding/end_user_onboarding_screen.dart';
import 'onboarding/founder_onboarding_screen.dart';
import 'onboarding/investor_onboarding_screen.dart';
import 'onboarding/reason_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Validate Supabase credentials before initialization
  if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) {
    print('ERROR: Supabase credentials are missing!');
    print('Make sure to run with --dart-define flags:');
    print('  --dart-define=SUPABASE_URL=your-url');
    print('  --dart-define=SUPABASE_ANON_KEY=your-key');
    // Still run the app so user sees an error message
    runApp(const StartupperApp());
    return;
  }
  
  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
    );
    print('Supabase initialized successfully');
  } catch (e, stackTrace) {
    print('ERROR: Failed to initialize Supabase: $e');
    print('Stack trace: $stackTrace');
    // Continue running the app - it will show an error when trying to use Supabase
  }
  
  runApp(const StartupperApp());
}

class StartupperApp extends StatelessWidget {
  const StartupperApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final initialRoute = Supabase.instance.client.auth.currentSession != null
        ? '/feed'
        : '/auth';
    return MaterialApp(
      title: 'Startupper',
      theme: AppTheme.light(),
      initialRoute: initialRoute,
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/onboarding/reason': (context) => const ReasonScreen(),
        '/onboarding/common': (context) => const CommonOnboardingScreen(),
        '/onboarding/founder': (context) => const FounderOnboardingScreen(),
        '/onboarding/investor': (context) => const InvestorOnboardingScreen(),
        '/onboarding/end_user': (context) => const EndUserOnboardingScreen(),
        '/feed': (context) => const FeedScreen(),
      },
    );
  }
}
