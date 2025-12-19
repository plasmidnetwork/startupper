import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../feed/feed_service.dart';
import '../feed/contact_request_models.dart';
import '../theme/snackbar.dart';
import 'startup_models.dart';
import 'startup_repository.dart';

class StartupDetailScreen extends StatefulWidget {
  const StartupDetailScreen({super.key, required this.startupId});

  final String startupId;

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  final _repo = StartupRepository();
  final _feedService = FeedService();
  StartupProfile? _startup;
  bool _loading = true;
  String? _error;
  bool _requesting = false;
  ContactRequestStatus? _status;

  bool get _isOwner =>
      _startup?.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _repo.fetchStartupById(widget.startupId);
      if (!mounted) return;
      if (s == null) {
        setState(() {
          _loading = false;
          _error = 'This startup is not available.';
        });
        return;
      }
      final status = await _loadConnectionStatus(s.userId);
      if (!mounted) return;
      setState(() {
        _startup = s;
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this startup.';
      });
    }
  }

  Future<ContactRequestStatus?> _loadConnectionStatus(
      String targetUserId) async {
    try {
      final sent = await _feedService.fetchContactRequests(outgoing: true);
      final match = sent.firstWhere(
        (r) => r.target.id == targetUserId,
        orElse: () => ContactRequest(
          id: '',
          requester:
              ContactRequestParty(id: '', name: '', role: '', headline: ''),
          target: ContactRequestParty(id: '', name: '', role: '', headline: ''),
          status: ContactRequestStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      if (match.id.isEmpty) return null;
      return match.status;
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestConnection() async {
    if (_requesting || _startup == null) return;
    final targetUserId = _startup!.userId;
    if (targetUserId.isEmpty) {
      showErrorSnackBar(context, 'Missing founder profile.');
      return;
    }
    setState(() => _requesting = true);
    try {
      await _feedService.requestIntro(targetUserId: targetUserId);
      if (!mounted) return;
      setState(() {
        _status = ContactRequestStatus.pending;
      });
      showSuccessSnackBar(context, 'Connection request sent');
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
            context, 'Could not send connection request right now.');
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit startup',
              onPressed: () async {
                final refreshed =
                    await Navigator.pushNamed(context, '/startups/edit');
                if (refreshed == true) {
                  await _load();
                }
              },
            ),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete startup page?'),
                          content: const Text(
                              'This will remove your startup page. You can recreate it later.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (!confirm) return;
                  try {
                    await StartupRepository().deleteMyStartup();
                    if (!mounted) return;
                    showSuccessSnackBar(context, 'Startup page deleted');
                    Navigator.pop(context, true);
                  } catch (_) {
                    if (mounted) {
                      showErrorSnackBar(
                          context, 'Could not delete your startup page.');
                    }
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete startup'),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge,
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
                )
              : _startup == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(startup: _startup!),
                          const SizedBox(height: 12),
                          _Meta(
                            startup: _startup!,
                            status: _status,
                            requesting: _requesting,
                            onConnect: _requestConnection,
                          ),
                          const SizedBox(height: 16),
                          _Links(startup: _startup!),
                        ],
                      ),
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.startup});

  final StartupProfile startup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final initial = startup.startupName.isNotEmpty
        ? startup.startupName[0].toUpperCase()
        : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: accent.withOpacity(0.12),
          backgroundImage:
              (startup.avatarUrl != null && startup.avatarUrl!.isNotEmpty)
                  ? NetworkImage(startup.avatarUrl!)
                  : null,
          child: (startup.avatarUrl == null || startup.avatarUrl!.isEmpty)
              ? Text(
                  initial,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                startup.startupName,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                startup.pitch,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.startup,
    required this.status,
    required this.requesting,
    required this.onConnect,
  });

  final StartupProfile startup;
  final ContactRequestStatus? status;
  final bool requesting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startup.stage.isNotEmpty) ...[
          Text(
            'Stage',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Chip(
            label: Text(startup.stage),
            visualDensity: VisualDensity.compact,
          ),
        ],
        if (startup.lookingFor.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          Text(
            'Looking for',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: startup.lookingFor
                .map((tag) => Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        if (startup.founderName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Founder',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _FounderProfile(
            startup: startup,
            status: status,
            requesting: requesting,
            onConnect: onConnect,
          ),
        ],
      ],
    );
  }
}

class _FounderProfile extends StatelessWidget {
  const _FounderProfile({
    required this.startup,
    required this.status,
    required this.requesting,
    required this.onConnect,
  });

  final StartupProfile startup;
  final ContactRequestStatus? status;
  final bool requesting;
  final VoidCallback onConnect;

  void _showFounderSheet(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final initial = startup.founderName.isNotEmpty
        ? startup.founderName[0].toUpperCase()
        : '?';

    final disabled = requesting ||
        status == ContactRequestStatus.pending ||
        status == ContactRequestStatus.accepted;
    final buttonLabel = () {
      if (status == ContactRequestStatus.accepted) return 'Connected';
      if (status == ContactRequestStatus.pending) return 'Request sent';
      return 'Request connection';
    }();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: accent.withValues(alpha: 0.12),
              backgroundImage: (startup.founderAvatarUrl != null &&
                      startup.founderAvatarUrl!.isNotEmpty)
                  ? NetworkImage(startup.founderAvatarUrl!)
                  : null,
              child: (startup.founderAvatarUrl == null ||
                      startup.founderAvatarUrl!.isEmpty)
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              startup.founderName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (startup.headline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                startup.headline,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (startup.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                startup.location,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: disabled
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        onConnect();
                      },
                child: requesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final initial = startup.founderName.isNotEmpty
        ? startup.founderName[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: () => _showFounderSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: accent.withValues(alpha: 0.12),
          backgroundImage: (startup.founderAvatarUrl != null &&
                  startup.founderAvatarUrl!.isNotEmpty)
              ? NetworkImage(startup.founderAvatarUrl!)
              : null,
          child: (startup.founderAvatarUrl == null ||
                  startup.founderAvatarUrl!.isEmpty)
              ? Text(
                  initial,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                startup.founderName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (startup.headline.isNotEmpty)
                Text(
                  startup.headline,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              if (startup.location.isNotEmpty)
                Text(
                  startup.location,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
        ),
      ],
        ),
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.startup});

  final StartupProfile startup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = <Widget>[];

    String _normalizeUrl(String raw) =>
        raw.startsWith('http') ? raw : 'https://$raw';

    void addLink(String label, String? value, {String? launchUrl}) {
      if (value == null || value.isEmpty) return;
      links.add(_LinkRow(label: label, value: value, launchUrl: launchUrl));
    }

    if (startup.website != null && startup.website!.isNotEmpty) {
      addLink('Website', startup.website,
          launchUrl: _normalizeUrl(startup.website!));
    }
    if (startup.demoVideo != null && startup.demoVideo!.isNotEmpty) {
      addLink('Demo video', startup.demoVideo,
          launchUrl: _normalizeUrl(startup.demoVideo!));
    }
    if (startup.appStoreId != null && startup.appStoreId!.isNotEmpty) {
      final id = startup.appStoreId!.trim();
      final launch =
          id.startsWith('http') ? id : 'https://apps.apple.com/app/id$id';
      addLink('App Store', id, launchUrl: launch);
    }
    if (startup.playStoreId != null && startup.playStoreId!.isNotEmpty) {
      final id = startup.playStoreId!.trim();
      final launch = id.startsWith('http')
          ? id
          : 'https://play.google.com/store/apps/details?id=$id';
      addLink('Play Store', id, launchUrl: launch);
    }

    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Links',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        ...links,
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(
      {required this.label, required this.value, this.launchUrl});

  final String label;
  final String value;
  final String? launchUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrl = launchUrl != null || value.startsWith('http') || value.startsWith('www');
    final openUrl = launchUrl ?? (value.startsWith('http') ? value : 'https://$value');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUrl)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open',
              onPressed: () async {
                final target = openUrl;
                final ok = await launchUrlString(
                  target,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  showErrorSnackBar(
                      context, 'Could not open link. Copied instead.');
                  await Clipboard.setData(ClipboardData(text: value));
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                showSuccessSnackBar(context, '$label copied');
              }
            },
          ),
        ],
      ),
    );
  }
}
