import 'package:flutter/material.dart';
import 'auth/auth_screen.dart';
import 'feed/feed_screen.dart';
import 'onboarding/common_onboarding_screen.dart';
import 'onboarding/end_user_onboarding_screen.dart';
import 'onboarding/founder_onboarding_screen.dart';
import 'onboarding/investor_onboarding_screen.dart';
import 'onboarding/reason_screen.dart';

void main() {
  runApp(const StartupperApp());
}

class StartupperApp extends StatelessWidget {
  const StartupperApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startupper',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/auth',
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
