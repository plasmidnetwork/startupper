import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/supabase_service.dart';
import '../theme/spacing.dart';

class FounderOnboardingScreen extends StatefulWidget {
  const FounderOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<FounderOnboardingScreen> createState() =>
      _FounderOnboardingScreenState();
}

class _FounderOnboardingScreenState extends State<FounderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startupNameController = TextEditingController();
  final _pitchController = TextEditingController();
  final _websiteController = TextEditingController();
  final _videoController = TextEditingController();
  final _appStoreIdController = TextEditingController();
  final _playStoreIdController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _saving = false;

  String _selectedStage = 'Idea';
  final List<String> _stages = ['Idea', 'Pre-seed', 'Seed', 'Series A+'];

  final Map<String, bool> _lookingFor = {
    'Investors': false,
    'Co-founder': false,
    'First hires': false,
    'Freelancers': false,
    'Beta users': false,
    'Advisors': false,
  };

  bool _isProductDetailsExpanded = false;

  @override
  void dispose() {
    _startupNameController.dispose();
    _pitchController.dispose();
    _websiteController.dispose();
    _videoController.dispose();
    _appStoreIdController.dispose();
    _playStoreIdController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (kBypassValidation) {
      Navigator.pushReplacementNamed(context, '/feed');
      return;
    }
    _saveFounder();
  }

  Future<void> _saveFounder() async {
    setState(() => _saving = true);
    try {
      await _supabaseService.upsertFounderDetails(
        startupName: _startupNameController.text.trim(),
        pitch: _pitchController.text.trim(),
        stage: _selectedStage,
        lookingFor: _lookingFor.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        demoVideo: _videoController.text.trim().isEmpty
            ? null
            : _videoController.text.trim(),
        appStoreId: _appStoreIdController.text.trim().isEmpty
            ? null
            : _appStoreIdController.text.trim(),
        playStoreId: _playStoreIdController.text.trim().isEmpty
            ? null
            : _playStoreIdController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save founder details: $e')),
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
        title: const Text('Founder Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your startup',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: gapLG),
              TextFormField(
                controller: _startupNameController,
                decoration: const InputDecoration(
                  labelText: 'Startup Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Startup name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: gapMD),
              TextFormField(
                controller: _pitchController,
                decoration: const InputDecoration(
                  labelText: 'One-liner Pitch *',
                  hintText: 'Describe your startup in one sentence',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb),
                ),
                maxLines: 2,
                maxLength: 300,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pitch is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: gapMD),
              DropdownButtonFormField<String>(
                initialValue: _selectedStage,
                decoration: const InputDecoration(
                  labelText: 'Stage *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: _stages
                    .map((stage) => DropdownMenuItem(
                          value: stage,
                          child: Text(stage),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStage = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a stage';
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lookingFor.keys.map((item) {
                  return FilterChip(
                    label: Text(item),
                    selected: _lookingFor[item]!,
                    onSelected: (selected) {
                      setState(() {
                        _lookingFor[item] = selected;
                      });
                    },
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: gapXL),
              ProductDetailsSection(
                isExpanded: _isProductDetailsExpanded,
                onToggle: () {
                  setState(() {
                    _isProductDetailsExpanded = !_isProductDetailsExpanded;
                  });
                },
                websiteController: _websiteController,
                videoController: _videoController,
                appStoreIdController: _appStoreIdController,
                playStoreIdController: _playStoreIdController,
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
    );
  }
}

class ProductDetailsSection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final TextEditingController websiteController;
  final TextEditingController videoController;
  final TextEditingController appStoreIdController;
  final TextEditingController playStoreIdController;

  const ProductDetailsSection({
    Key? key,
    required this.isExpanded,
    required this.onToggle,
    required this.websiteController,
    required this.videoController,
    required this.appStoreIdController,
    required this.playStoreIdController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Do you have a product ready?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('No'),
              selected: !isExpanded,
              onSelected: (selected) {
                if (selected && isExpanded) {
                  onToggle();
                }
              },
              showCheckmark: false,
            ),
            FilterChip(
              label: const Text('Yes'),
              selected: isExpanded,
              onSelected: (selected) {
                if (selected && !isExpanded) {
                  onToggle();
                }
              },
              showCheckmark: false,
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          hintText: 'https://yourstartup.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.language),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: videoController,
                        decoration: const InputDecoration(
                          labelText: 'Demo video',
                          hintText: 'https://youtu.be/...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.play_circle_outline),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: appStoreIdController,
                        decoration: const InputDecoration(
                          labelText: 'iOS App Store ID',
                          hintText: 'e.g., 1234567890',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.apple),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: playStoreIdController,
                        decoration: const InputDecoration(
                          labelText: 'Google Play package name',
                          hintText: 'e.g., com.myapp.mobile',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.android),
                        ),
                        keyboardType: TextInputType.text,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
