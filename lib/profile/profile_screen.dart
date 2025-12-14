import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/snackbar.dart';
import '../theme/loading_overlay.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = SupabaseService();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _roleDetails;
  bool _loading = true;
  String? _error;
  bool _editing = false;
  bool _saving = false;
  String _role = 'Member';

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _freelancing = false;
  final ImagePicker _picker = ImagePicker();
  // Role-specific controllers
  final _founderStartupCtrl = TextEditingController();
  final _founderPitchCtrl = TextEditingController();
  final _founderStageCtrl = TextEditingController();
  final _founderLookingCtrl = TextEditingController();

  final _investorTypeCtrl = TextEditingController();
  final _investorTicketCtrl = TextEditingController();
  final _investorStagesCtrl = TextEditingController();

  final _enduserRoleCtrl = TextEditingController();
  final _enduserExpCtrl = TextEditingController();
  final _enduserInterestsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _headlineCtrl.dispose();
    _locationCtrl.dispose();
    _founderStartupCtrl.dispose();
    _founderPitchCtrl.dispose();
    _founderStageCtrl.dispose();
    _founderLookingCtrl.dispose();
    _investorTypeCtrl.dispose();
    _investorTicketCtrl.dispose();
    _investorStagesCtrl.dispose();
    _enduserRoleCtrl.dispose();
    _enduserExpCtrl.dispose();
    _enduserInterestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prof = await _service.fetchProfile(forceRefresh: true);
      final role = prof?['role']?.toString();
      Map<String, dynamic>? roleDetails;
      if (role != null && role.isNotEmpty) {
        roleDetails = await _service.fetchRoleDetails(role);
      }
      if (!mounted) return;
      setState(() {
        _profile = prof;
        _roleDetails = roleDetails;
        _loading = false;
        _role = prof?['role']?.toString() ?? 'Member';
        _hydrateForm(prof);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile.';
        _loading = false;
      });
    }
  }

  void _openAvatarPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _saving = true;
      });
      final file = File(picked.path);
      await _service.upsertProfile(
        fullName: _nameCtrl.text.trim().isEmpty
            ? (_profile?['full_name']?.toString() ?? '')
            : _nameCtrl.text.trim(),
        headline: _headlineCtrl.text.trim().isEmpty
            ? (_profile?['headline']?.toString() ?? '')
            : _headlineCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? (_profile?['location']?.toString() ?? '')
            : _locationCtrl.text.trim(),
        role: _profile?['role']?.toString() ?? 'Member',
        availableForFreelancing: _freelancing,
        avatarFile: file,
      );
      await _load();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Avatar updated');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      showErrorSnackBar(
        context,
        'Could not update avatar. Please try again.',
      );
    }
  }

  void _hydrateForm(Map<String, dynamic>? prof) {
    _nameCtrl.text = prof?['full_name']?.toString() ?? '';
    _headlineCtrl.text = prof?['headline']?.toString() ?? '';
    _locationCtrl.text = prof?['location']?.toString() ?? '';
    _freelancing = prof?['available_for_freelancing'] == true;

    final role = _role.toLowerCase();
    final details = _roleDetails;
    if (role == 'founder') {
      _founderStartupCtrl.text = details?['startup_name']?.toString() ?? '';
      _founderPitchCtrl.text = details?['pitch']?.toString() ?? '';
      _founderStageCtrl.text = details?['stage']?.toString() ?? '';
      _founderLookingCtrl.text =
          (details?['looking_for'] as List?)?.join(', ') ?? '';
    } else if (role == 'investor') {
      _investorTypeCtrl.text = details?['investor_type']?.toString() ?? '';
      _investorTicketCtrl.text = details?['ticket_size']?.toString() ?? '';
      _investorStagesCtrl.text =
          (details?['stages'] as List?)?.join(', ') ?? '';
    } else if (role == 'end-user' || role == 'enduser') {
      _enduserRoleCtrl.text = details?['main_role']?.toString() ?? '';
      _enduserExpCtrl.text = details?['experience_level']?.toString() ?? '';
      _enduserInterestsCtrl.text =
          (details?['interests'] as List?)?.join(', ') ?? '';
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
    });
    try {
      await _service.upsertProfile(
        fullName: _nameCtrl.text.trim(),
        headline: _headlineCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        role: _role,
        availableForFreelancing: _freelancing,
      );
      await _saveRoleDetails(_role);
      final updated = {
        ...?_profile,
        'full_name': _nameCtrl.text.trim(),
        'headline': _headlineCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'available_for_freelancing': _freelancing,
        'role': _role,
      };
      setState(() {
        _profile = updated;
        _editing = false;
        _saving = false;
      });
      if (!mounted) return;
      showSuccessSnackBar(context, 'Profile updated');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      showErrorSnackBar(
        context,
        'Could not save profile. Please try again.',
        onRetry: _save,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_profile != null)
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        _editing = !_editing;
                        _hydrateForm(_profile);
                      });
                    },
              child: Text(
                _editing ? 'Cancel' : 'Edit',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading || _saving,
        message: _saving ? 'Saving profile...' : 'Loading profile...',
        child: RefreshIndicator(
          onRefresh: _load,
          child: _error != null
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _ProfileHeader(
                      profile: _profile,
                      loading: _saving,
                      onChangeAvatar: _openAvatarPicker,
                    ),
                    const SizedBox(height: 24),
                    _editing
                        ? _ProfileEditForm(
                            formKey: _formKey,
                            nameCtrl: _nameCtrl,
                            headlineCtrl: _headlineCtrl,
                            locationCtrl: _locationCtrl,
                            freelancing: _freelancing,
                            onFreelancingChanged: (v) => setState(() {
                              _freelancing = v;
                            }),
                            onSave: _save,
                            role: _role,
                            onRoleChanged: _handleRoleChange,
                            founderStartupCtrl: _founderStartupCtrl,
                            founderPitchCtrl: _founderPitchCtrl,
                            founderStageCtrl: _founderStageCtrl,
                            founderLookingCtrl: _founderLookingCtrl,
                            investorTypeCtrl: _investorTypeCtrl,
                            investorTicketCtrl: _investorTicketCtrl,
                            investorStagesCtrl: _investorStagesCtrl,
                            enduserRoleCtrl: _enduserRoleCtrl,
                            enduserExpCtrl: _enduserExpCtrl,
                            enduserInterestsCtrl: _enduserInterestsCtrl,
                          )
                        : _ProfileFields(
                            profile: _profile,
                            roleDetails: _roleDetails,
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _saveRoleDetails(String role) async {
    switch (role.toLowerCase()) {
      case 'founder':
        await _service.upsertFounderDetails(
          startupName: _founderStartupCtrl.text.trim(),
          pitch: _founderPitchCtrl.text.trim(),
          stage: _founderStageCtrl.text.trim(),
          lookingFor: _csvToList(_founderLookingCtrl.text),
        );
        break;
      case 'investor':
        await _service.upsertInvestorDetails(
          investorType: _investorTypeCtrl.text.trim(),
          ticketSize: _investorTicketCtrl.text.trim(),
          stages: _csvToList(_investorStagesCtrl.text),
        );
        break;
      case 'end-user':
      case 'enduser':
        await _service.upsertEndUserDetails(
          mainRole: _enduserRoleCtrl.text.trim(),
          experienceLevel: _enduserExpCtrl.text.trim(),
          interests: _csvToList(_enduserInterestsCtrl.text),
        );
        break;
      default:
        break;
    }
  }

  List<String> _csvToList(String input) =>
      input.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  Future<void> _handleRoleChange(String newRole) async {
    if (_saving) return;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Switch role?'),
            content: const Text(
                'Changing your role will overwrite any existing details for that role. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Switch'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _role = newRole;
      _roleDetails = null;
      _founderStartupCtrl.clear();
      _founderPitchCtrl.clear();
      _founderStageCtrl.clear();
      _founderLookingCtrl.clear();
      _investorTypeCtrl.clear();
      _investorTicketCtrl.clear();
      _investorStagesCtrl.clear();
      _enduserRoleCtrl.clear();
      _enduserExpCtrl.clear();
      _enduserInterestsCtrl.clear();
    });
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onChangeAvatar,
    required this.loading,
  });

  final Map<String, dynamic>? profile;
  final VoidCallback onChangeAvatar;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?['avatar_url'] as String?;
    final name = profile?['full_name']?.toString() ?? 'Your name';
    final headline = profile?['headline']?.toString() ?? 'Headline';
    final email = profile?['email']?.toString() ?? '';

    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child:
                  avatarUrl == null ? const Icon(Icons.person, size: 32) : null,
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: loading ? null : onChangeAvatar,
                tooltip: 'Change avatar',
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                headline,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileFields extends StatelessWidget {
  const _ProfileFields({required this.profile, required this.roleDetails});

  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? roleDetails;

  @override
  Widget build(BuildContext context) {
    final role = profile?['role']?.toString() ?? 'Not set';
    final location = profile?['location']?.toString() ?? 'Unknown';
    final freelancing =
        profile?['available_for_freelancing'] == true ? 'Yes' : 'No';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Role', role),
            _field('Location', location),
            _field('Available for freelancing', freelancing),
            if (role.toLowerCase() == 'founder' && roleDetails != null) ...[
              const Divider(),
              const Text(
                'Founder details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _field(
                  'Startup', roleDetails?['startup_name']?.toString() ?? '-'),
              _field('Pitch', roleDetails?['pitch']?.toString() ?? '-'),
              _field('Stage', roleDetails?['stage']?.toString() ?? '-'),
              _field(
                  'Looking for',
                  (roleDetails?['looking_for'] as List?)
                          ?.join(', ')
                          .toString() ??
                      '-'),
            ] else if (role.toLowerCase() == 'investor' &&
                roleDetails != null) ...[
              const Divider(),
              const Text(
                'Investor details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _field('Type', roleDetails?['investor_type']?.toString() ?? '-'),
              _field('Ticket size',
                  roleDetails?['ticket_size']?.toString() ?? '-'),
              _field(
                  'Stages',
                  (roleDetails?['stages'] as List?)?.join(', ').toString() ??
                      '-'),
            ] else if ((role.toLowerCase() == 'end-user' ||
                    role.toLowerCase() == 'enduser') &&
                roleDetails != null) ...[
              const Divider(),
              const Text(
                'End-user details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _field('Main role', roleDetails?['main_role']?.toString() ?? '-'),
              _field('Experience level',
                  roleDetails?['experience_level']?.toString() ?? '-'),
              _field(
                  'Interests',
                  (roleDetails?['interests'] as List?)?.join(', ').toString() ??
                      '-'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _ProfileEditForm extends StatelessWidget {
  const _ProfileEditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.headlineCtrl,
    required this.locationCtrl,
    required this.freelancing,
    required this.onFreelancingChanged,
    required this.onSave,
    required this.role,
    required this.onRoleChanged,
    this.founderStartupCtrl,
    this.founderPitchCtrl,
    this.founderStageCtrl,
    this.founderLookingCtrl,
    this.investorTypeCtrl,
    this.investorTicketCtrl,
    this.investorStagesCtrl,
    this.enduserRoleCtrl,
    this.enduserExpCtrl,
    this.enduserInterestsCtrl,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController headlineCtrl;
  final TextEditingController locationCtrl;
  final bool freelancing;
  final ValueChanged<bool> onFreelancingChanged;
  final VoidCallback onSave;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController? founderStartupCtrl;
  final TextEditingController? founderPitchCtrl;
  final TextEditingController? founderStageCtrl;
  final TextEditingController? founderLookingCtrl;
  final TextEditingController? investorTypeCtrl;
  final TextEditingController? investorTicketCtrl;
  final TextEditingController? investorStagesCtrl;
  final TextEditingController? enduserRoleCtrl;
  final TextEditingController? enduserExpCtrl;
  final TextEditingController? enduserInterestsCtrl;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Founder', child: Text('Founder')),
              DropdownMenuItem(value: 'Investor', child: Text('Investor')),
              DropdownMenuItem(value: 'End-user', child: Text('End-user')),
            ],
            onChanged: (val) {
              if (val != null) onRoleChanged(val);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: headlineCtrl,
            decoration: const InputDecoration(
              labelText: 'Headline',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Headline is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Location is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: freelancing,
            onChanged: onFreelancingChanged,
            title: const Text('Available for freelancing'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          _roleSpecificFields(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _roleSpecificFields() {
    final r = role.toLowerCase();
    if (r == 'founder') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const Text(
            'Founder details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: founderStartupCtrl,
            decoration: const InputDecoration(
              labelText: 'Startup name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Startup name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: founderPitchCtrl,
            decoration: const InputDecoration(
              labelText: 'Pitch',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Pitch is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: founderStageCtrl,
            decoration: const InputDecoration(
              labelText: 'Stage',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: founderLookingCtrl,
            decoration: const InputDecoration(
              labelText: 'Looking for (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    } else if (r == 'investor') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const Text(
            'Investor details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: investorTypeCtrl,
            decoration: const InputDecoration(
              labelText: 'Investor type',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Type is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: investorTicketCtrl,
            decoration: const InputDecoration(
              labelText: 'Ticket size',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ticket size is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: investorStagesCtrl,
            decoration: const InputDecoration(
              labelText: 'Stages (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    } else if (r == 'end-user' || r == 'enduser') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const Text(
            'End-user details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: enduserRoleCtrl,
            decoration: const InputDecoration(
              labelText: 'Main role',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Main role is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: enduserExpCtrl,
            decoration: const InputDecoration(
              labelText: 'Experience level',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Experience level is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: enduserInterestsCtrl,
            decoration: const InputDecoration(
              labelText: 'Interests (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
