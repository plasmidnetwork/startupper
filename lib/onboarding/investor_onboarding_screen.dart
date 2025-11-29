import 'package:flutter/material.dart';
import '../app_config.dart';

class InvestorOnboardingScreen extends StatefulWidget {
  const InvestorOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<InvestorOnboardingScreen> createState() =>
      _InvestorOnboardingScreenState();
}

class _InvestorOnboardingScreenState extends State<InvestorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketSizeController = TextEditingController();

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
          const SnackBar(content: Text('Select at least one stage')),
        );
        return;
      }
    }
    Navigator.pushReplacementNamed(context, '/feed');
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your investment focus',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _investorType,
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
                    return 'Select an investor type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                    return 'Ticket size is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Stages interested in',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleFinish,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
