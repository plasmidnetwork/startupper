import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_config.dart';
import '../services/supabase_service.dart';
import '../theme/snackbar.dart';
import '../theme/loading_overlay.dart';

// Auth/login screen with validation and bypass flag support.
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  final _supabaseService = SupabaseService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _ensureProfile(User user) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('profiles').upsert(
        {
          'id': user.id,
          'email': user.email,
        },
        onConflict: 'id',
      );
    } catch (e) {
      // Non-fatal for signup flow; log to console.
      // ignore: avoid_print
      print('Profile upsert skipped: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (kBypassValidation) {
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
      return;
    }
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      if (!mounted) return;
      if (res.session != null && res.user != null) {
        await _ensureProfile(res.user!);
        await _redirectAfterAuth();
      } else {
        showErrorSnackBar(context, 'Login failed. Check your credentials.',
            onRetry: _loading ? null : _handleLogin);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Login failed: ${e.message}',
          onRetry: _loading ? null : _handleLogin);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context,
          'Could not log in. Check your connection and try again.',
          onRetry: _loading ? null : _handleLogin);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (kBypassValidation) {
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
      return;
    }
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kEmailRedirectTo.isEmpty ? null : kEmailRedirectTo,
      );
      if (!mounted) return;
      if (res.session != null && res.user != null) {
        await _ensureProfile(res.user!);
        await _redirectAfterAuth();
      } else {
        showSuccessSnackBar(
          context,
          'Signup succeeded. Please verify your email to continue.',
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Signup failed: ${e.message}',
          onRetry: _loading ? null : _handleSignup);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context,
          'Could not sign up. Check your connection and try again.',
          onRetry: _loading ? null : _handleSignup);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redirectAfterAuth() async {
    try {
      final profile = await _supabaseService.fetchProfile();
      if (!mounted) return;
      final role = profile?['role'] as String?;
      if (role != null && role.isNotEmpty) {
        Navigator.pushNamedAndRemoveUntil(context, '/feed', (route) => false);
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding/reason');
      }
    } catch (e) {
      if (!mounted) return;
      // On failure to fetch profile, default to onboarding.
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startupper'),
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        message: 'Working on it...',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 4),
                        ),
                      const Text(
                        'Welcome to Startupper',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex =
                              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(trimmed)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : _handleSignup,
                        child: const Text('Don\'t have an account? Sign up'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
