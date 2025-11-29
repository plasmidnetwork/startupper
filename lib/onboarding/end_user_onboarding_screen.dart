import 'package:flutter/material.dart';
import '../app_config.dart';

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
          const SnackBar(content: Text('Select at least one interest')),
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
        title: const Text('Your Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your interests',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _mainRole,
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
                    return 'Select a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _experienceLevel,
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
                    return 'Select an experience level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'What are you looking for?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
