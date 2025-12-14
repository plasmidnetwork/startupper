import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/contact_request_models.dart';
import '../feed/feed_service.dart';
import '../theme/loading_overlay.dart';
import '../theme/snackbar.dart';
import 'startup_models.dart';
import 'startup_repository.dart';

class StartupDiscoveryScreen extends StatefulWidget {
  const StartupDiscoveryScreen({super.key});

  @override
  State<StartupDiscoveryScreen> createState() => _StartupDiscoveryScreenState();
}

class _StartupDiscoveryScreenState extends State<StartupDiscoveryScreen> {
  final _repo = StartupRepository();
  final _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _stageFilters = {};
  final Set<String> _lookingFilters = {};
  final Set<String> _introDisabled = {};
  final Map<String, ContactRequestStatus> _introStatuses = {};
  final Map<String, bool> _sendingIntro = {};
  List<StartupProfile> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _searchTerm = '';
  String? _error;
  static const int _pageSize = 10;

  static const _stageOptions = ['Idea', 'Pre-seed', 'Seed', 'Series A+'];
  static const _lookingOptions = [
    'Investors',
    'Co-founder',
    'First hires',
    'Freelancers',
    'Beta users',
    'Advisors',
  ];

  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (_isLoggedIn) {
      _loadPendingIntros();
      _loadInitial();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingIntros() async {
    try {
      final sent = await _feedService.fetchContactRequests(outgoing: true);
      if (!mounted) return;
      final targets = sent
          .where((r) => r.target.id.isNotEmpty && r.status != ContactRequestStatus.declined)
          .map((r) => r.target.id)
          .toSet();
      final statusMap = <String, ContactRequestStatus>{};
      for (final r in sent) {
        if (r.target.id.isNotEmpty) {
          statusMap[r.target.id] = r.status;
        }
      }
      setState(() {
        _introDisabled
          ..clear()
          ..addAll(targets);
        _introStatuses
          ..clear()
          ..addAll(statusMap);
      });
    } catch (_) {
      // Best-effort; failures fall back to enabling all intros.
    }
  }

  Future<void> _loadInitial() async {
    if (!_isLoggedIn) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchStartups(
        limit: _pageSize,
        search: _searchTerm,
        stages: _stageFilters.toList(),
        lookingFor: _lookingFilters.toList(),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _hasMore = true;
        _loading = false;
        _error = 'Could not load startups. Pull to retry.';
      });
    }
  }

  Future<void> _refresh() async {
    if (!_isLoggedIn) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchStartups(
        limit: _pageSize,
        search: _searchTerm,
        stages: _stageFilters.toList(),
        lookingFor: _lookingFilters.toList(),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = 'Could not refresh startups.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !_isLoggedIn) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final page = await _repo.loadMore(
        _items.length,
        limit: _pageSize,
        search: _searchTerm,
        stages: _stageFilters.toList(),
        lookingFor: _lookingFilters.toList(),
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = 'Could not load more right now.';
      });
    }
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _applySearch(String term) {
    setState(() {
      _searchTerm = term.trim();
    });
    _loadInitial();
  }

  void _toggleStage(String stage) {
    setState(() {
      if (_stageFilters.contains(stage)) {
        _stageFilters.remove(stage);
      } else {
        _stageFilters.add(stage);
      }
    });
    _loadInitial();
  }

  void _toggleLooking(String tag) {
    setState(() {
      if (_lookingFilters.contains(tag)) {
        _lookingFilters.remove(tag);
      } else {
        _lookingFilters.add(tag);
      }
    });
    _loadInitial();
  }

  void _resetFilters() {
    setState(() {
      _stageFilters.clear();
      _lookingFilters.clear();
    });
    _loadInitial();
  }

  Future<void> _requestIntro(StartupProfile startup) async {
    if (!_isLoggedIn) {
      showErrorSnackBar(context, 'Please sign in to request intros.');
      return;
    }
    if (startup.userId.isEmpty ||
        _sendingIntro[startup.userId] == true ||
        _introDisabled.contains(startup.userId)) {
      return;
    }

    final controller = TextEditingController();
    final message = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request intro to ${startup.founderName}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            hintText: 'Add quick context for the intro',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (message == null) return;

    setState(() {
      _sendingIntro[startup.userId] = true;
    });
    try {
      await _feedService.requestIntro(
        targetUserId: startup.userId,
        message: message.trim().isEmpty ? null : message.trim(),
      );
      if (!mounted) return;
      setState(() {
        _introDisabled.add(startup.userId);
        _introStatuses[startup.userId] = ContactRequestStatus.pending;
      });
      showSuccessSnackBar(context, 'Intro request sent');
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not send intro right now.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingIntro.remove(startup.userId);
        });
      }
    }
  }

  Future<void> _openDetails(StartupProfile startup) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _StartupDetailSheet(
          startup: startup,
          introStatus: _introStatuses[startup.userId],
          introDisabled: _introDisabled.contains(startup.userId),
          onRequestIntro: () {
            Navigator.pop(context);
            _requestIntro(startup);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Startups')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Sign in to discover startups',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/auth', (route) => false);
                  },
                  child: const Text('Go to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Intros',
            onPressed: () {
              Navigator.pushNamed(context, '/intros');
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading && _items.isEmpty,
        message: 'Loading startups...',
        child: RefreshIndicator(
          onRefresh: _refresh,
          displacement: 80,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover startups',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _applySearch,
                        decoration: InputDecoration(
                          hintText: 'Search by name or pitch...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: () =>
                                      _applySearch(_searchController.text),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._stageOptions.map(
                            (stage) => FilterChip(
                              label: Text(stage),
                              selected: _stageFilters.contains(stage),
                              onSelected: (_) => _toggleStage(stage),
                            ),
                          ),
                          ..._lookingOptions.map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: _lookingFilters.contains(tag),
                              onSelected: (_) => _toggleLooking(tag),
                            ),
                          ),
                          if (_stageFilters.isNotEmpty ||
                              _lookingFilters.isNotEmpty)
                            ActionChip(
                              label: const Text('Reset'),
                              onPressed: _resetFilters,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadInitial,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!_loading && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No startups match your filters.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search or filters.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final startup = _items[index];
                      final disabled = _introDisabled.contains(startup.userId);
                      final status = _introStatuses[startup.userId];
                      final sending = _sendingIntro[startup.userId] == true;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                            16, index == 0 ? 8 : 12, 16, 0),
                        child: _StartupCard(
                          startup: startup,
                          introDisabled: disabled,
                          introStatus: status,
                          sendingIntro: sending,
                          onRequestIntro: () => _requestIntro(startup),
                          onOpenDetails: () => _openDetails(startup),
                        ),
                      );
                    },
                    childCount: _items.length,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : _refreshing
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Refreshing...',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              )
                            : !_hasMore
                                ? Text(
                                    'You\'re all caught up',
                                    style: theme.textTheme.bodySmall,
                                  )
                                : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  const _StartupCard({
    required this.startup,
    required this.introDisabled,
    required this.introStatus,
    required this.sendingIntro,
    required this.onRequestIntro,
    required this.onOpenDetails,
  });

  final StartupProfile startup;
  final bool introDisabled;
  final ContactRequestStatus? introStatus;
  final bool sendingIntro;
  final VoidCallback onRequestIntro;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final initial =
        startup.startupName.isNotEmpty ? startup.startupName[0].toUpperCase() : '?';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  backgroundImage: (startup.avatarUrl != null &&
                          startup.avatarUrl!.isNotEmpty)
                      ? NetworkImage(startup.avatarUrl!)
                      : null,
                  child: (startup.avatarUrl == null ||
                          startup.avatarUrl!.isEmpty)
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
                        startup.startupName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${startup.founderName}${startup.location.isNotEmpty ? ' · ${startup.location}' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (startup.stage.isNotEmpty)
                  Chip(
                    label: Text(startup.stage),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              startup.pitch,
              style: theme.textTheme.bodyMedium,
            ),
            if (startup.lookingFor.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: startup.lookingFor
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (introStatus != null) ...[
              const SizedBox(height: 10),
              Chip(
                label: Text(_introLabel(introStatus)),
                visualDensity: VisualDensity.compact,
                backgroundColor: _introColor(introStatus, accent),
                labelStyle: theme.textTheme.labelMedium
                    ?.copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: introDisabled || sendingIntro ? null : onRequestIntro,
                    child: sendingIntro
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(introDisabled ? 'Intro sent' : 'Request intro'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onOpenDetails,
                  child: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupDetailSheet extends StatelessWidget {
  const _StartupDetailSheet({
    required this.startup,
    required this.introStatus,
    required this.introDisabled,
    required this.onRequestIntro,
  });

  final StartupProfile startup;
  final ContactRequestStatus? introStatus;
  final bool introDisabled;
  final VoidCallback onRequestIntro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final initial =
        startup.startupName.isNotEmpty ? startup.startupName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.14),
                  backgroundImage: (startup.avatarUrl != null &&
                          startup.avatarUrl!.isNotEmpty)
                      ? NetworkImage(startup.avatarUrl!)
                      : null,
                  child: (startup.avatarUrl == null ||
                          startup.avatarUrl!.isEmpty)
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                        '${startup.founderName}${startup.location.isNotEmpty ? ' · ${startup.location}' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (startup.stage.isNotEmpty)
                  Chip(
                    label: Text(startup.stage),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              startup.pitch,
              style: theme.textTheme.bodyMedium,
            ),
            if (startup.lookingFor.isNotEmpty) ...[
              const SizedBox(height: 12),
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
            if (startup.website != null && startup.website!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LinkRow(label: 'Website', value: startup.website!),
            ],
            if (startup.demoVideo != null && startup.demoVideo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LinkRow(label: 'Demo video', value: startup.demoVideo!),
            ],
            if (startup.appStoreId != null && startup.appStoreId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LinkRow(label: 'App Store ID', value: startup.appStoreId!),
            ],
            if (startup.playStoreId != null &&
                startup.playStoreId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LinkRow(label: 'Play Store ID', value: startup.playStoreId!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: introDisabled ? null : onRequestIntro,
                    child: Text(introDisabled
                        ? _introLabel(introStatus)
                        : 'Request intro'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
    );
  }
}

String _introLabel(ContactRequestStatus? status) {
  switch (status) {
    case ContactRequestStatus.accepted:
      return 'Intro accepted';
    case ContactRequestStatus.declined:
      return 'Intro declined';
    case ContactRequestStatus.pending:
    case null:
      return 'Intro sent';
  }
}

Color _introColor(ContactRequestStatus? status, Color accent) {
  switch (status) {
    case ContactRequestStatus.accepted:
      return Colors.green.withValues(alpha: 0.14);
    case ContactRequestStatus.declined:
      return Colors.red.withValues(alpha: 0.14);
    case ContactRequestStatus.pending:
    case null:
      return accent.withValues(alpha: 0.14);
  }
}
