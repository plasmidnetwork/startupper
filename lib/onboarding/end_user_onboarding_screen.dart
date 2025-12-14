import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/supabase_service.dart';
import '../theme/spacing.dart';
import 'onboarding_progress.dart';
import '../theme/snackbar.dart';
import '../theme/loading_overlay.dart';

class EndUserOnboardingScreen extends StatefulWidget {
  const EndUserOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<EndUserOnboardingScreen> createState() =>
      _EndUserOnboardingScreenState();
}

class _EndUserOnboardingScreenState extends State<EndUserOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _mainRole = 'Developer';
  final List<String> _roles = [
    'Developer',
    'Designer',
    'Product',
    'Growth',
    'Sales',
    'Ops',
    'Student',
    'Other',
  ];

  String _experienceLevel = 'Mid';
  final List<String> _experienceLevels = [
    'Junior',
    'Mid',
    'Senior',
    'Lead',
    'Student',
  ];

  final Map<String, bool> _lookingFor = {
    'Join a startup': false,
    'Freelance for startups': false,
    'Test products': false,
    'Maybe co-found later': false,
  };
  final _supabaseService = SupabaseService();
  bool _saving = false;

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (!kBypassValidation) {
      final hasInterest = _lookingFor.values.any((v) => v);
      if (!hasInterest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pick at least one interest to tailor matches.')),
        );
        return;
      }
    }
    if (kBypassValidation) {
      Navigator.pushReplacementNamed(context, '/feed');
      return;
    }
    _saveEndUser();
  }

  Future<void> _saveEndUser() async {
    setState(() => _saving = true);
    try {
      await _supabaseService.upsertEndUserDetails(
        mainRole: _mainRole,
        experienceLevel: _experienceLevel,
        interests: _lookingFor.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Could not save your details. Check your connection and try again.',
        onRetry: _saving ? null : _saveEndUser,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Details'),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        message: 'Saving your details...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingProgress(
                  currentStep: 3,
                  totalSteps: 3,
                  label: _saving ? 'Saving your details...' : 'Your interests',
                ),
                if (_saving) ...[
                  const SizedBox(height: gapSM),
                  const LinearProgressIndicator(minHeight: 4),
                ],
                const SizedBox(height: gapLG),
                const Text(
                  'Tell us about your interests',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: gapLG),
                DropdownButtonFormField<String>(
                  initialValue: _mainRole,
                  decoration: const InputDecoration(
                    labelText: 'Main Role *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: _roles
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _mainRole = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select your main role.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: gapMD),
                DropdownButtonFormField<String>(
                  initialValue: _experienceLevel,
                  decoration: const InputDecoration(
                    labelText: 'Experience Level *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bar_chart),
                  ),
                  items: _experienceLevels
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _experienceLevel = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select your experience level.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: gapLG),
                const Text(
                  'What are you looking for?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: gapSM),
                ..._lookingFor.keys.map((interest) {
                  return CheckboxListTile(
                    title: Text(interest),
                    value: _lookingFor[interest],
                    onChanged: (value) {
                      setState(() {
                        _lookingFor[interest] = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
                const SizedBox(height: gapXL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _handleBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _handleFinish,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Finish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
