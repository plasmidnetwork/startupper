import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_models.dart';
import 'feed_repository.dart';
import '../services/supabase_service.dart';
import 'feed_service.dart';
import '../theme/snackbar.dart';
import '../theme/loading_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_request_models.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Set<String> _activeFilters = {'Personalized'};
  final _repo = FeedRepository();
  final _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  SharedPreferences? _prefs;
  List<FeedCardData> _items = [];
  final Set<String> _pendingIntroTargets = {};
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 10;
  String _searchTerm = '';
  String? _userRole;
  String? _error;
  final bool _showSeedDialog = kDebugMode;
  bool get _isLoggedIn => Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    _initFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initFeed() async {
    await _loadPrefs();
    if (!mounted) return;
    await _loadPendingIntroTargets();
    if (!mounted) return;
    await _loadUserRole();
    if (!mounted) return;
    await _loadInitial();
  }

  Future<void> _loadPendingIntroTargets() async {
    try {
      final sent = await _feedService.fetchContactRequests(outgoing: true);
      if (!mounted) return;
      final targets = sent
          .where((r) => r.status != ContactRequestStatus.declined)
          .map((r) => r.target.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      setState(() {
        _pendingIntroTargets
          ..clear()
          ..addAll(targets);
      });
    } catch (_) {
      // ignore failures; intro disabling will be best-effort.
    }
  }

  Future<void> _openAuthorProfile(FeedAuthor author) async {
    final isIntroDisabled = author.id != null &&
        author.id!.isNotEmpty &&
        _pendingIntroTargets.contains(author.id);
    bool requesting = false;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendIntro() async {
              if (requesting || author.id == null || author.id!.isEmpty) return;
              final msg = await showDialog<String?>(
                context: context,
                builder: (context) => _IntroDialog(author: author),
              );
              if (msg == null) return;
              setSheetState(() {
                requesting = true;
              });
              try {
                await _feedService.requestIntro(
                  targetUserId: author.id!,
                  message: msg.trim().isEmpty ? null : msg.trim(),
                );
                if (!mounted) return;
                setState(() {
                  if (author.id != null) _pendingIntroTargets.add(author.id!);
                });
                Navigator.pop(context);
                showSuccessSnackBar(context, 'Intro request sent');
              } catch (_) {
                if (mounted) {
                  showErrorSnackBar(context, 'Could not send intro right now.');
                }
              } finally {
                setSheetState(() {
                  requesting = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: (author.avatarUrl != null &&
                                author.avatarUrl!.isNotEmpty)
                            ? NetworkImage(author.avatarUrl!)
                            : null,
                        child: (author.avatarUrl == null ||
                                author.avatarUrl!.isEmpty)
                            ? Text(
                                author.name.isNotEmpty
                                    ? author.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
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
                              author.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${author.role}${author.affiliation.isNotEmpty ? ' · ${author.affiliation}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: isIntroDisabled
                              ? 'You already sent an intro to this member'
                              : '',
                          child: ElevatedButton(
                            onPressed: (author.id == null ||
                                    author.id!.isEmpty ||
                                    isIntroDisabled ||
                                    requesting)
                                ? null
                                : sendIntro,
                            child: requesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isIntroDisabled
                                    ? 'Intro sent'
                                    : 'Request intro'),
                          ),
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
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadUserRole() async {
    try {
      final profile = await SupabaseService().fetchProfile();
      if (!mounted) return;
      final role = profile?['role']?.toString();
      if (role != null && role.isNotEmpty) {
        setState(() {
          _userRole = role;
        });
        if (_prefs == null || (_prefs?.getStringList('feed_filters')?.isEmpty ?? true)) {
          _applyRoleDefaults(role);
        }
        if (_activeFilters.contains('Personalized')) {
          await _loadInitial();
        }
      }
    } catch (_) {
      // Ignore role fetch errors; personalization will be skipped.
    }
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchFeed(
        limit: _pageSize,
        search: _searchTerm,
        tags: _tagFiltersFromActive(),
        types: _typeFiltersFromActive(),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _hasMore = true;
        _loading = false;
        _error = 'Could not load feed. Pull to retry.';
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchFeed(
        limit: _pageSize,
        search: _searchTerm,
        tags: _tagFiltersFromActive(),
        types: _typeFiltersFromActive(),
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _hasMore = true;
        _error = 'Could not refresh feed. Pull to retry.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final page = await _repo.loadMore(
        _items.length,
        limit: _pageSize,
        search: _searchTerm,
        tags: _tagFiltersFromActive(),
        types: _typeFiltersFromActive(),
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = true;
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

  List<String> _tagFiltersFromActive() {
    final tagMap = {
      'AI': 'AI',
      'Fintech': 'Fintech',
      'Seed': 'Seed',
      'Hiring': 'Hiring',
      'Raising': 'Raising',
    };
    final tags = <String>[];
    for (final filter in _activeFilters) {
      final tag = tagMap[filter];
      if (tag != null) tags.add(tag);
    }
    if (_activeFilters.contains('Personalized') && _userRole != null) {
      tags.add(_userRole!);
    }
    return tags;
  }

  List<FeedCardType> _typeFiltersFromActive() {
    final types = <FeedCardType>[];
    if (_activeFilters.contains('Missions')) {
      types.add(FeedCardType.mission);
    }
    return types;
  }

  Future<void> _loadPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedFilters = _prefs?.getStringList('feed_filters');
    final savedSearch = _prefs?.getString('feed_search') ?? '';
    if (savedFilters != null && savedFilters.isNotEmpty) {
      _activeFilters
        ..clear()
        ..addAll(savedFilters);
    }
    _searchTerm = savedSearch;
    _searchController.text = savedSearch;
  }

  void _savePrefs() {
    _prefs?.setStringList('feed_filters', _activeFilters.toList());
    _prefs?.setString('feed_search', _searchTerm);
  }

  void _applyRoleDefaults(String role) {
    final r = role.toLowerCase();
    if (_activeFilters.isEmpty) {
      _activeFilters.add('Personalized');
      if (r == 'founder') {
        _activeFilters.add('Raising');
      } else if (r == 'investor') {
        _activeFilters.add('Seed');
      } else if (r == 'end-user' || r == 'enduser') {
        _activeFilters.add('Missions');
      }
    }
  }

  void _applySearch(String term) {
    final trimmed = term.trim();
    setState(() {
      _searchTerm = trimmed;
    });
    _savePrefs();
    _loadInitial();
  }

  void _resetFilters() {
    setState(() {
      _activeFilters
        ..clear()
        ..add('Personalized');
    });
    _savePrefs();
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Feed'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Please sign in to view the feed.',
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
        title: const Text('Feed'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Intros',
            onPressed: () {
              Navigator.pushNamed(context, '/intros');
            },
          ),
          if (_showSeedDialog && _isLoggedIn)
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Post update',
              onPressed: _openComposeDialog,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/auth', (route) => false);
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading && _items.isEmpty,
        message: 'Loading feed...',
        child: SafeArea(
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
                          'What’s happening',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _applySearch,
                          decoration: InputDecoration(
                            hintText: 'Search updates, asks, tags...',
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
                                    onPressed: () => _applySearch(
                                        _searchController.text.trim()),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FiltersRow(
                          activeFilters: _activeFilters,
                          onToggle: (filter) {
                            setState(() {
                              if (_activeFilters.contains(filter)) {
                                _activeFilters.remove(filter);
                              } else {
                                _activeFilters.add(filter);
                              }
                            });
                            _savePrefs();
                            _loadInitial();
                          },
                          onReset: _resetFilters,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const _FeedSkeleton()
                else if (_error != null)
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
                else if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No updates yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pull to refresh or adjust filters',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Featured section commented out for now
                  // if (featured.isNotEmpty)
                  //   SliverToBoxAdapter(
                  //     child: Padding(
                  //       padding: const EdgeInsets.only(bottom: 8),
                  //       child: SizedBox(
                  //         height: 250,
                  //         child: ListView.separated(
                  //           padding: const EdgeInsets.symmetric(horizontal: 16),
                  //           scrollDirection: Axis.horizontal,
                  //           itemBuilder: (context, index) => _FeaturedCard(
                  //             data: featured[index],
                  //           ),
                  //           separatorBuilder: (context, index) =>
                  //               const SizedBox(width: 12),
                  //           itemCount: featured.length,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _items[index];
                        final introPending = item.author.id != null &&
                            _pendingIntroTargets.contains(item.author.id);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                              16, index == 0 ? 16 : 12, 16, 4),
                          child: FeedCard(
                            data: item,
                            introPending: introPending,
                            onIntroSent: () {
                              final id = item.author.id;
                              if (id == null || id.isEmpty) return;
                              setState(() {
                                _pendingIntroTargets.add(id);
                              });
                            },
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
                                        'Refreshing feed...',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  )
                                : !_hasMore
                                    ? Text(
                                        'You\'re all caught up',
                                        style: theme.textTheme.bodySmall,
                                      )
                                    : Text(
                                        ' ',
                                        style: theme.textTheme.bodySmall,
                                      ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openComposeDialog() {
    showDialog(
      context: context,
      builder: (context) => _ComposeDialog(
        userRole: _userRole,
        onPost: (payload) async {
          if (!_isLoggedIn) {
            if (!mounted) return;
            showErrorSnackBar(context, 'Please sign in to post.');
            return;
          }
          try {
            await _feedService.createFeedItem(
              type: payload.type,
              title: payload.title,
              subtitle: payload.subtitle,
              ask: payload.ask,
              tags: payload.tags,
              reward: payload.reward,
              metrics: payload.metrics,
              featured: payload.featured,
              userRoleTag: payload.userRoleTag,
            );
            await _refresh();
            if (!mounted) return;
            showSuccessSnackBar(context, 'Posted to feed');
          } catch (e) {
            if (!mounted) return;
            showErrorSnackBar(
              context,
              'Could not post right now. Check your connection and try again.',
            );
          }
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tags,
    this.ask,
    this.reward,
    this.featured = false,
    this.userRole,
  });

  final FeedCardType type;
  final String title;
  final String subtitle;
  final List<String> tags;
  final String? ask;
  final String? reward;
  final bool featured;
  final String? userRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewTags = {
      ...tags,
      if (userRole != null && userRole!.isNotEmpty) userRole!,
    }.toList();
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preview',
                  style: theme.textTheme.labelLarge,
                ),
                Chip(
                  label: Text(type.name),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            if (ask != null) ...[
              const SizedBox(height: 8),
              _AskChip(label: ask!),
            ],
            if (reward != null) ...[
              const SizedBox(height: 8),
              Text(
                reward!,
                style: theme.textTheme.labelMedium,
              ),
            ],
            if (previewTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: previewTags
                    .map((t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (featured) ...[
              const SizedBox(height: 8),
              Text(
                'Featured',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FeedCard extends StatelessWidget {
  const FeedCard({
    Key? key,
    required this.data,
    this.introPending = false,
    this.onIntroSent,
    this.onAuthorTap,
  }) : super(key: key);

  final FeedCardData data;
  final bool introPending;
  final VoidCallback? onIntroSent;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    switch (data.type) {
      case FeedCardType.highlight:
        return _HighlightCard(data: data, onAuthorTap: onAuthorTap);
      case FeedCardType.mission:
        return _MissionCard(data: data, onAuthorTap: onAuthorTap);
      case FeedCardType.investor:
        return _InvestorCard(
          data: data,
          introPending: introPending,
          onIntroSent: onIntroSent,
          onAuthorTap: onAuthorTap,
        );
      case FeedCardType.update:
        return _UpdateCard(data: data, onAuthorTap: onAuthorTap);
    }
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.data, this.onAuthorTap});

  final FeedCardData data;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarNameRow(author: data.author, onTap: onAuthorTap),
            const SizedBox(height: 12),
            Text(
              data.subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            if (data.metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              MetricPills(metrics: data.metrics),
            ],
            if (data.ask != null) ...[
              const SizedBox(height: 8),
              _AskChip(label: data.ask!),
            ],
            const SizedBox(height: 12),
            ActionBar(accent: _roleAccent(data.author.role, theme)),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.data, this.onAuthorTap});

  final FeedCardData data;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 96),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.white.withValues(alpha: 0.85),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarNameRow(author: data.author, onTap: onAuthorTap),
                if (data.ask != null) ...[
                  const SizedBox(height: 10),
                  _AskChip(label: data.ask!),
                ],
                if (data.metrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MetricPills(metrics: data.metrics),
                ],
                const SizedBox(height: 10),
                ActionBar(accent: accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.data, this.onAuthorTap});

  final FeedCardData data;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: AvatarNameRow(author: data.author, onTap: onAuthorTap)),
                if (data.reward != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.reward!,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: accent, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            if (data.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Mission claimed: ${data.title}')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Claim'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mission saved')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestorCard extends StatefulWidget {
  const _InvestorCard({
    required this.data,
    this.introPending = false,
    this.onIntroSent,
    this.onAuthorTap,
  });

  final FeedCardData data;
  final bool introPending;
  final VoidCallback? onIntroSent;
  final VoidCallback? onAuthorTap;

  @override
  State<_InvestorCard> createState() => _InvestorCardState();
}

class _InvestorCardState extends State<_InvestorCard> {
  bool _requesting = false;
  bool _introSent = false;

  @override
  void initState() {
    super.initState();
    _introSent = widget.introPending;
  }

  @override
  void didUpdateWidget(covariant _InvestorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.introPending && !_introSent) {
      setState(() {
        _introSent = true;
      });
    }
  }

  Future<void> _handleRequestIntro() async {
    if (_requesting || _introSent) return;
    final authorId = widget.data.author.id;
    if (authorId == null || authorId.isEmpty) {
      showErrorSnackBar(context, 'Missing member profile for intro.');
      return;
    }
    final message = await showDialog<String?>(
      context: context,
      builder: (context) => _IntroDialog(author: widget.data.author),
    );
    if (message == null) return;

    setState(() => _requesting = true);
    try {
      await FeedService().requestIntro(
        targetUserId: authorId,
        feedItemId: widget.data.id,
        message: message.trim().isEmpty ? null : message.trim(),
      );
      if (!mounted) return;
      setState(() => _introSent = true);
      widget.onIntroSent?.call();
      showSuccessSnackBar(context, 'Intro request sent');
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not send intro right now.');
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final accent = _roleAccent(data.author.role, theme);
    final disabled = _requesting || _introSent || widget.introPending;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarNameRow(author: data.author, onTap: widget.onAuthorTap),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            if (data.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: accent.withValues(alpha: 0.12),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (data.ask != null) ...[
              const SizedBox(height: 10),
              _AskChip(label: data.ask!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Tooltip(
                  message:
                      disabled ? 'You already sent an intro to this member' : '',
                  child: ElevatedButton(
                    onPressed: disabled ? null : _handleRequestIntro,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: _requesting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(disabled ? 'Intro sent' : 'Request intro'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('One-pager shared')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Share one-pager'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AvatarNameRow extends StatelessWidget {
  const AvatarNameRow({Key? key, required this.author, this.onTap})
      : super(key: key);

  final FeedAuthor author;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(author.role, theme);
    final initial = author.name.isNotEmpty ? author.name[0].toUpperCase() : '?';

    final content = Row(
      children: [
        CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.16),
          backgroundImage:
              (author.avatarUrl != null && author.avatarUrl!.isNotEmpty)
                  ? NetworkImage(author.avatarUrl!)
                  : null,
          child: (author.avatarUrl == null || author.avatarUrl!.isEmpty)
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
                author.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${author.role} · ${author.affiliation} · ${author.timeAgo}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      child: content,
    );
  }
}

class MetricPills extends StatelessWidget {
  const MetricPills({Key? key, required this.metrics}) : super(key: key);

  final List<MetricHighlight> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics
          .map(
            (metric) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: metric.color?.withValues(alpha: 0.12) ??
                    theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: metric.color ?? theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    metric.label,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class ActionBar extends StatelessWidget {
  const ActionBar({Key? key, required this.accent}) : super(key: key);

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You applauded this update')),
            );
          },
          icon: const Icon(Icons.emoji_events_outlined, size: 18),
          label: const Text('Applaud'),
        ),
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comments coming soon')),
            );
          },
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Comment'),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Interest sent!')),
            );
          },
          child: Text(
            'Signal interest',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.data});

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_element
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            data.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: data.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening ${data.title}')),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Open'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AskChip extends StatelessWidget {
  const _AskChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.activeFilters,
    required this.onToggle,
    required this.onReset,
  });

  final Set<String> activeFilters;
  final void Function(String) onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final filters = [
      'Personalized',
      'AI',
      'Fintech',
      'Seed',
      'Hiring',
      'Raising',
      'Missions',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...filters
            .map(
              (filter) => FilterChip(
                label: Text(filter),
                selected: activeFilters.contains(filter),
                onSelected: (_) => onToggle(filter),
              ),
            )
            .toList(),
        if (activeFilters.isNotEmpty)
          ActionChip(
            label: const Text('Reset'),
            onPressed: onReset,
          ),
      ],
    );
  }
}

class _ComposePayload {
  _ComposePayload({
    required this.type,
    required this.title,
    required this.subtitle,
    this.ask,
    this.tags = const [],
    this.metrics = const [],
    this.reward,
    this.featured = false,
    this.userRoleTag,
  });

  final FeedCardType type;
  final String title;
  final String subtitle;
  final String? ask;
  final List<String> tags;
  final List<MetricHighlight> metrics;
  final String? reward;
  final bool featured;
  final String? userRoleTag;
}

class _ComposeDialog extends StatefulWidget {
  const _ComposeDialog({required this.onPost, this.userRole});

  final Future<void> Function(_ComposePayload) onPost;
  final String? userRole;

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _formKey = GlobalKey<FormState>();
  FeedCardType _type = FeedCardType.update;
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _askCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  bool _featured = false;
  bool _posting = false;
  static const int _maxTags = 6;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_updatePreview);
    _subtitleCtrl.addListener(_updatePreview);
    _askCtrl.addListener(_updatePreview);
    _tagsCtrl.addListener(_updatePreview);
    _rewardCtrl.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_updatePreview);
    _subtitleCtrl.removeListener(_updatePreview);
    _askCtrl.removeListener(_updatePreview);
    _tagsCtrl.removeListener(_updatePreview);
    _rewardCtrl.removeListener(_updatePreview);
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _askCtrl.dispose();
    _tagsCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {});
  }

  Future<void> _handlePost() async {
    if (_posting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _posting = true;
    });
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tags.length > _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limit to $_maxTags tags')),
      );
      setState(() => _posting = false);
      return;
    }
    final payload = _ComposePayload(
      type: _type,
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      ask: _askCtrl.text.trim().isEmpty ? null : _askCtrl.text.trim(),
      tags: tags,
      reward: _rewardCtrl.text.trim().isEmpty ? null : _rewardCtrl.text.trim(),
      metrics: const [],
      featured: _featured,
      userRoleTag: widget.userRole,
    );
    final shouldPost = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Post this update?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${payload.type.name}'),
                const SizedBox(height: 8),
                Text('Title: ${payload.title}'),
                const SizedBox(height: 4),
                Text(
                  payload.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (payload.ask != null) ...[
                  const SizedBox(height: 8),
                  Text('Ask: ${payload.ask}'),
                ],
                if (payload.reward != null) ...[
                  const SizedBox(height: 4),
                  Text('Reward: ${payload.reward}'),
                ],
                if (payload.tags.isNotEmpty || payload.userRoleTag != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tags: ${(payload.tags + (payload.userRoleTag != null ? [
                        payload.userRoleTag!
                      ] : [])).join(', ')}',
                  ),
                ],
                if (payload.featured) ...[
                  const SizedBox(height: 8),
                  const Text('Featured'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldPost) {
      setState(() => _posting = false);
      return;
    }

    await widget.onPost(payload);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post to feed'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<FeedCardType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _type = val);
                },
                items: FeedCardType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLength: 80,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (v.trim().length < 4) {
                    return 'Title too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subtitle',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 280,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Subtitle is required';
                  }
                  if (v.trim().length < 8) {
                    return 'Subtitle too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _askCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ask (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 140,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsCtrl,
                decoration: InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: const OutlineInputBorder(),
                  helperText: widget.userRole == null
                      ? null
                      : 'Your role "${widget.userRole}" will be auto-tagged',
                ),
                maxLength: 120,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rewardCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reward (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _featured,
                onChanged: (val) => setState(() => _featured = val),
                title: const Text('Featured'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              _PreviewCard(
                type: _type,
                title: _titleCtrl.text.trim().isEmpty
                    ? 'Preview title'
                    : _titleCtrl.text.trim(),
                subtitle: _subtitleCtrl.text.trim().isEmpty
                    ? 'Preview subtitle'
                    : _subtitleCtrl.text.trim(),
                ask: _askCtrl.text.trim().isEmpty ? null : _askCtrl.text.trim(),
                tags: _tagsCtrl.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList(),
                reward: _rewardCtrl.text.trim().isEmpty
                    ? null
                    : _rewardCtrl.text.trim(),
                featured: _featured,
                userRole: widget.userRole,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _posting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _posting ? null : _handlePost,
          child: _posting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }
}

class _IntroDialog extends StatefulWidget {
  const _IntroDialog({required this.author});

  final FeedAuthor author;

  @override
  State<_IntroDialog> createState() => _IntroDialogState();
}

class _IntroDialogState extends State<_IntroDialog> {
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Request intro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send a short note to ${widget.author.name}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              border: OutlineInputBorder(),
              hintText: 'Context or what you are looking for',
            ),
            maxLines: 3,
            maxLength: 240,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _messageCtrl.text),
          child: const Text('Send request'),
        ),
      ],
    );
  }
}

Color _roleAccent(String role, ThemeData theme) {
  switch (role.toLowerCase()) {
    case 'founder':
      return Colors.blueAccent;
    case 'investor':
      return Colors.green;
    case 'builder':
    case 'end-user':
      return Colors.orange;
    default:
      return theme.colorScheme.primary;
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 12, 16, 4),
            child: const _SkeletonCard(),
          );
        },
        childCount: 3,
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(base, width: 120, height: 14),
            const SizedBox(height: 10),
            _block(base, width: double.infinity, height: 14),
            const SizedBox(height: 8),
            _block(base, width: double.infinity, height: 14),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip(base, width: 70),
                const SizedBox(width: 8),
                _chip(base, width: 70),
                const SizedBox(width: 8),
                _chip(base, width: 70),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _block(base, width: 80, height: 12),
                const SizedBox(width: 12),
                _block(base, width: 80, height: 12),
                const Spacer(),
                _block(base, width: 40, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(Color base, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _chip(Color base, {required double width}) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
