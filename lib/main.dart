import 'dart:async';
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
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'profile/profile_screen.dart';
import 'feed/contact_requests_screen.dart';
import 'feed/feed_item_screen.dart';
import 'feed/feed_models.dart';
import 'feed/contact_request_models.dart';
import 'feed/intro_chat_screen.dart';
import 'startups/startup_discovery_screen.dart';
import 'startups/startup_edit_screen.dart';
import 'startups/startup_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) {
    print('ERROR: Supabase credentials are missing!');
    print('Make sure to run with --dart-define flags:');
    print('  --dart-define=SUPABASE_URL=your-url');
    print('  --dart-define=SUPABASE_ANON_KEY=your-key');
    runApp(const StartupperApp(
      supabaseReady: false,
      startupErrorMessage:
          'Supabase credentials are missing. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
    ));
    return;
  }

  bool supabaseReady = false;
  String? startupError;
  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
    );
    supabaseReady = true;
    print('Supabase initialized successfully');
  } catch (e, stackTrace) {
    startupError = 'Failed to initialize Supabase: $e';
    print('ERROR: $startupError');
    print('Stack trace: $stackTrace');
  }

  runApp(StartupperApp(
    supabaseReady: supabaseReady,
    startupErrorMessage: startupError,
  ));
}

class StartupperApp extends StatefulWidget {
  const StartupperApp({
    Key? key,
    required this.supabaseReady,
    this.startupErrorMessage,
  }) : super(key: key);

  final bool supabaseReady;
  final String? startupErrorMessage;

  @override
  State<StartupperApp> createState() => _StartupperAppState();
}

class _StartupperAppState extends State<StartupperApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;
  Session? _session;

  @override
  void initState() {
    super.initState();
    if (widget.supabaseReady) {
      _session = Supabase.instance.client.auth.currentSession;
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
        (event) {
          setState(() {
            _session = event.session;
          });
          _handleAuthChange(event.event, event.session);
        },
      );
      if (_session != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _redirectForSession(_session);
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(
      AuthChangeEvent event, Session? session) async {
    switch (event) {
      case AuthChangeEvent.signedOut:
        _navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/auth', (route) => false);
        break;
      case AuthChangeEvent.signedIn:
        await _redirectForSession(session);
        break;
      default:
        break;
    }
  }

  Future<void> _redirectForSession(Session? session) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (session == null) {
      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
      return;
    }

    try {
      final profile = await SupabaseService().fetchProfile();
      final hasRole = profile?['role']?.toString().isNotEmpty == true;
      navigator.pushNamedAndRemoveUntil(
        hasRole ? '/feed' : '/onboarding/reason',
        (route) => false,
      );
    } catch (_) {
      navigator.pushNamedAndRemoveUntil('/onboarding/reason', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.supabaseReady) {
      return MaterialApp(
        title: 'Startupper',
        theme: AppTheme.light(),
        home: StartupErrorScreen(
          message: widget.startupErrorMessage ??
              'Supabase is not configured. Please set the required dart-defines.',
        ),
      );
    }

    final initialRoute = _session != null ? '/feed' : '/auth';

    return MaterialApp(
      title: 'Startupper',
      theme: AppTheme.light(),
      navigatorKey: _navigatorKey,
      initialRoute: initialRoute,
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/onboarding/reason': (context) => const ReasonScreen(),
        '/onboarding/common': (context) => const CommonOnboardingScreen(),
        '/onboarding/founder': (context) => const FounderOnboardingScreen(),
        '/onboarding/investor': (context) => const InvestorOnboardingScreen(),
        '/onboarding/end_user': (context) => const EndUserOnboardingScreen(),
        '/feed': (context) => const FeedScreen(),
        '/startups': (context) => const StartupDiscoveryScreen(),
        '/startups/edit': (context) => const StartupEditScreen(),
        '/startups/detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? id;
          if (args is Map && args['id'] != null) {
            id = args['id']?.toString();
          }
          if (id == null || id.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing startup id')),
            );
          }
          return StartupDetailScreen(startupId: id);
        },
        '/profile': (context) => const ProfileScreen(),
        '/intros': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int initialTab = 0;
          if (args is Map && args['initialTab'] is int) {
            initialTab = args['initialTab'] as int;
          }
          return ContactRequestsScreen(initialTab: initialTab);
        },
        '/intros/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! Map) {
            return const Scaffold(
              body: Center(child: Text('Missing connection chat args')),
            );
          }
          final introId = args['introId']?.toString();
          final other = args['other'];
          if (introId == null || other is! ContactRequestParty) {
            return const Scaffold(
              body: Center(child: Text('Missing connection chat args')),
            );
          }
          return IntroChatScreen(introId: introId, other: other);
        },
        '/feed/item': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? id;
          FeedCardData? data;
          bool focusComments = false;
          ContactRequestStatus? initialIntroStatus;
          bool initialIntroPending = false;
          bool initialIsLiked = false;
          int? initialLikeCount;
          if (args is Map) {
            id = args['id']?.toString();
            final raw = args['data'];
            if (raw is FeedCardData) {
              data = raw;
            }
            final fc = args['focusComments'];
            if (fc is bool) {
              focusComments = fc;
            }
            final introStatusArg = args['introStatus'];
            if (introStatusArg is ContactRequestStatus) {
              initialIntroStatus = introStatusArg;
            }
            final introPendingArg = args['introPending'];
            if (introPendingArg is bool) {
              initialIntroPending = introPendingArg;
            }
            final likedArg = args['isLiked'];
            if (likedArg is bool) {
              initialIsLiked = likedArg;
            }
            final likeCountArg = args['likeCountOverride'];
            if (likeCountArg is int) {
              initialLikeCount = likeCountArg;
            }
          }
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Missing feed item id')),
            );
          }
          return FeedItemScreen(
            id: id,
            initial: data,
            focusComments: focusComments,
            initialIntroStatus: initialIntroStatus,
            initialIntroPending: initialIntroPending,
            initialIsLiked: initialIsLiked,
            initialLikeCount: initialLikeCount,
          );
        },
      },
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({Key? key, required this.message}) : super(key: key);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'Startup configuration needed',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Run with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
