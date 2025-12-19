import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/feed_service.dart';
import '../theme/snackbar.dart';
import 'startup_repository.dart';
import 'startup_models.dart';

class StartupEditScreen extends StatefulWidget {
  const StartupEditScreen({super.key});

  @override
  State<StartupEditScreen> createState() => _StartupEditScreenState();
}

class _StartupEditScreenState extends State<StartupEditScreen> {
  final _repo = StartupRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();
  final _stageCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _demoCtrl = TextEditingController();
  final _appStoreCtrl = TextEditingController();
  final _playStoreCtrl = TextEditingController();
  final Set<String> _looking = {};
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  static const _stages = ['Idea', 'Pre-seed', 'Seed', 'Series A+'];
  static const _lookingOptions = [
    'Investors',
    'Co-founder',
    'First hires',
    'Freelancers',
    'Beta users',
    'Advisors',
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = (await FeedService().uploadMediaBytes(
          bytes: bytes,
          filename: picked.name,
          contentType: 'image/${picked.name.toLowerCase().endsWith('png') ? 'png' : 'jpeg'}',
          isVideo: false,
        ))
            .url;
      } else {
        url = (await FeedService()
                .uploadMedia(io.File(picked.path)))
            .url;
      }
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
      });
      showSuccessSnackBar(context, 'Logo updated');
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not upload logo.');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pitchCtrl.dispose();
    _stageCtrl.dispose();
    _websiteCtrl.dispose();
    _demoCtrl.dispose();
    _appStoreCtrl.dispose();
    _playStoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final existing = await _repo.fetchMyStartup();
      if (existing != null && mounted) {
        _nameCtrl.text = existing.startupName;
        _pitchCtrl.text = existing.pitch;
        _stageCtrl.text = existing.stage;
        _websiteCtrl.text = existing.website ?? '';
        _demoCtrl.text = existing.demoVideo ?? '';
        _appStoreCtrl.text = existing.appStoreId ?? '';
        _playStoreCtrl.text = existing.playStoreId ?? '';
        _avatarUrl = existing.avatarUrl;
        _looking
          ..clear()
          ..addAll(existing.lookingFor);
      }
    } catch (_) {
      // Ignore prefill errors
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _repo.upsertStartup(
        startupName: _nameCtrl.text.trim(),
        pitch: _pitchCtrl.text.trim(),
        stage: _stageCtrl.text.trim(),
        lookingFor: _looking.toList(),
        avatarUrl: _avatarUrl,
        website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        demoVideo: _demoCtrl.text.trim().isEmpty ? null : _demoCtrl.text.trim(),
        appStoreId:
            _appStoreCtrl.text.trim().isEmpty ? null : _appStoreCtrl.text.trim(),
        playStoreId:
            _playStoreCtrl.text.trim().isEmpty ? null : _playStoreCtrl.text.trim(),
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Startup page saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not save startup. ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (Supabase.instance.client.auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Startup page')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Sign in to create a startup page.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup page'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: (_avatarUrl != null &&
                                  _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.business, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                          icon: _uploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_camera),
                          label: Text(_avatarUrl == null || _avatarUrl!.isEmpty
                              ? 'Add logo'
                              : 'Change logo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Startup name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pitchCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Pitch',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _stageCtrl.text.isNotEmpty ? _stageCtrl.text : null,
                      items: {
                        ..._stages,
                        if (_stageCtrl.text.isNotEmpty) _stageCtrl.text,
                      }
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _stageCtrl.text = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Stage',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Select a stage' : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Looking for',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _lookingOptions
                          .map(
                            (opt) => FilterChip(
                              label: Text(opt),
                              selected: _looking.contains(opt),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _looking.add(opt);
                                  } else {
                                    _looking.remove(opt);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _websiteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Website (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _demoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Demo video URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appStoreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'App Store ID (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _playStoreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Play Store ID (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save startup page'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
