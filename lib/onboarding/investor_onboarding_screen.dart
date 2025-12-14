import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/supabase_service.dart';
import '../theme/spacing.dart';
import 'onboarding_progress.dart';
import '../theme/snackbar.dart';
import '../theme/loading_overlay.dart';

class InvestorOnboardingScreen extends StatefulWidget {
  const InvestorOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<InvestorOnboardingScreen> createState() =>
      _InvestorOnboardingScreenState();
}

class _InvestorOnboardingScreenState extends State<InvestorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketSizeController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _saving = false;

  String _investorType = 'Angel';
  final List<String> _investorTypes = [
    'Angel',
    'VC',
    'Syndicate',
    'Accelerator',
    'Family office',
    'Corporate VC',
  ];

  final Map<String, bool> _stagesInterested = {
    'Idea': false,
    'Pre-seed': false,
    'Seed': false,
    'Series A+': false,
  };

  @override
  void dispose() {
    _ticketSizeController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (!kBypassValidation) {
      final selectedStage = _stagesInterested.values.any((v) => v);
      if (!selectedStage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pick at least one stage you invest in.')),
        );
        return;
      }
    }
    if (kBypassValidation) {
      Navigator.pushReplacementNamed(context, '/feed');
      return;
    }
    _saveInvestor();
  }

  Future<void> _saveInvestor() async {
    setState(() => _saving = true);
    try {
      await _supabaseService.upsertInvestorDetails(
        investorType: _investorType,
        ticketSize: _ticketSizeController.text.trim(),
        stages: _stagesInterested.entries
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
        'Could not save your investor details. Check your connection and try again.',
        onRetry: _saving ? null : _saveInvestor,
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
        title: const Text('Investor Details'),
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
                  label: _saving ? 'Saving your details...' : 'Investor details',
                ),
                if (_saving) ...[
                  const SizedBox(height: gapSM),
                  const LinearProgressIndicator(minHeight: 4),
                ],
                const SizedBox(height: gapLG),
                const Text(
                  'Tell us about your investment focus',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: gapLG),
                DropdownButtonFormField<String>(
                  initialValue: _investorType,
                  decoration: const InputDecoration(
                    labelText: 'Investor Type *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: _investorTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _investorType = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select your investor type.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: gapMD),
                TextFormField(
                  controller: _ticketSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Typical Ticket Size *',
                    hintText: 'e.g., \$25K - \$100K',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add your typical ticket size range.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: gapLG),
                const Text(
                  'Stages interested in',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: gapSM),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _stagesInterested.keys.map((stage) {
                    return FilterChip(
                      label: Text(stage),
                      selected: _stagesInterested[stage]!,
                      onSelected: (selected) {
                        setState(() {
                          _stagesInterested[stage] = selected;
                        });
                      },
                    );
                  }).toList(),
                ),
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
