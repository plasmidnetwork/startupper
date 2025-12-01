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
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
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
