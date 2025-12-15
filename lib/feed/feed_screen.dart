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
import 'package:flutter/services.dart';
import '../app_config.dart';
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
  final _profileService = SupabaseService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  SharedPreferences? _prefs;
  List<FeedCardData> _items = [];
  final Set<String> _pendingIntroTargets = {};
  final Map<String, ContactRequestStatus> _introStatusByTarget = {};
  final Set<String> _likedIds = {};
  final Map<String, int> _likeOverrides = {};
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
      final pendingTargets = sent
          .where((r) => r.status == ContactRequestStatus.pending)
          .map((r) => r.target.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      final statusMap = <String, ContactRequestStatus>{};
      for (final r in sent) {
        if (r.target.id.isNotEmpty) {
          statusMap[r.target.id] = r.status;
        }
      }
      setState(() {
        _pendingIntroTargets
          ..clear()
          ..addAll(pendingTargets);
        _introStatusByTarget
          ..clear()
          ..addAll(statusMap);
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
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text(author.role),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (author.timeAgo.isNotEmpty)
                                  Chip(
                                    label: Text('Posted ${author.timeAgo} ago'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (author.affiliation.isNotEmpty)
                                  Chip(
                                    label: Text(author.affiliation),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (author.id != null && author.id!.isNotEmpty)
                              FutureBuilder<Map<String, dynamic>?>(
                                future: _profileService.fetchRoleDetailsForUser(
                                    author.id!, author.role),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  final d = snap.data;
                                  if (d == null) return const SizedBox.shrink();
                                  return _RoleDetailChips(
                                    role: author.role,
                                    details: d,
                                  );
                                },
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

  void _openFeedDetail(FeedCardData data, {bool focusComments = false}) {
    Navigator.pushNamed(
      context,
      '/feed/item',
      arguments: {
        'id': data.id,
        'data': data,
        'focusComments': focusComments,
        'introStatus': data.author.id != null
            ? _introStatusByTarget[data.author.id!]
            : null,
        'introPending': data.author.id != null &&
            _pendingIntroTargets.contains(data.author.id),
        'isLiked': _likedIds.contains(data.id),
        'likeCountOverride': _likeOverrides[data.id],
      },
    );
  }

  void _openIntros({int initialTab = 0}) {
    Navigator.pushNamed(context, '/intros', arguments: {'initialTab': initialTab});
  }

  Future<void> _copyFeedLink({bool useWeb = false}) async {
    final rawBase = useWeb && kFeedWebLinkBase.isNotEmpty
        ? kFeedWebLinkBase
        : kFeedLinkBase;
    if (useWeb && kFeedWebLinkBase.isEmpty) {
      showErrorSnackBar(
          context, 'Web link base not set. Set FEED_WEB_LINK_BASE or copy app link.');
    }
    final base = rawBase.endsWith('/') ? rawBase : '$rawBase/';
    final link = base;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    showSuccessSnackBar(context, 'Feed link copied');
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

  void _handleLike(FeedCardData data) async {
    final id = data.id;
    if (id.isEmpty) return;
    final currentlyLiked = _likedIds.contains(id);
    final currentCount = _likeOverrides[id] ?? data.likeCount;
    setState(() {
      if (currentlyLiked) {
        _likedIds.remove(id);
        _likeOverrides[id] = currentCount > 0 ? currentCount - 1 : 0;
      } else {
        _likedIds.add(id);
        _likeOverrides[id] = currentCount + 1;
      }
    });
    try {
      if (currentlyLiked) {
        await _feedService.unlikeFeedItem(id);
      } else {
        await _feedService.likeFeedItem(id);
      }
    } catch (_) {
      // Revert on failure
      setState(() {
        if (currentlyLiked) {
          _likedIds.add(id);
          _likeOverrides[id] = currentCount;
        } else {
          _likedIds.remove(id);
          _likeOverrides[id] = currentCount;
        }
      });
      if (mounted) {
        showErrorSnackBar(context, 'Could not update like right now.');
      }
    }
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
            icon: const Icon(Icons.apartment_outlined),
            tooltip: 'Startups',
            onPressed: () {
              Navigator.pushNamed(context, '/startups');
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Copy feed link',
            onSelected: (choice) {
              _copyFeedLink(useWeb: choice == 'web');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'app',
                child: Text('Copy app link'),
              ),
              const PopupMenuItem(
                value: 'web',
                child: Text('Copy web link'),
              ),
            ],
            icon: const Icon(Icons.link),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Intros',
            onPressed: () {
              _openIntros(initialTab: 0);
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
              _repo.clearCache();
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
                        final introStatus = item.author.id != null
                            ? _introStatusByTarget[item.author.id!]
                            : null;
                        final introPending = introStatus == ContactRequestStatus.pending ||
                            (introStatus == null &&
                                item.author.id != null &&
                                _pendingIntroTargets.contains(item.author.id));
                        final likeCount =
                            _likeOverrides[item.id] ?? item.likeCount;
                        final isLiked = _likedIds.contains(item.id);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                              16, index == 0 ? 16 : 12, 16, 4),
                          child: FeedCard(
                            data: item,
                            introPending: introPending,
                            introStatus: introStatus,
                            onIntroSent: () {
                              final id = item.author.id;
                              if (id == null || id.isEmpty) return;
                              setState(() {
                                _pendingIntroTargets.add(id);
                              });
                            },
                            onAuthorTap: () => _openAuthorProfile(item.author),
                            onTap: () => _openFeedDetail(item),
                            onComment: () =>
                                _openFeedDetail(item, focusComments: true),
                            onIntroStatusTap: () => _openIntros(initialTab: 1),
                            onLike: () => _handleLike(item),
                            isLiked: isLiked,
                            likeCountOverride: likeCount,
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
    this.introStatus,
    this.onIntroSent,
    this.onAuthorTap,
    this.onTap,
    this.onIntroStatusTap,
    this.onComment,
    this.onLike,
    this.isLiked = false,
    this.likeCountOverride,
  }) : super(key: key);

  final FeedCardData data;
  final bool introPending;
  final ContactRequestStatus? introStatus;
  final VoidCallback? onIntroSent;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final VoidCallback? onIntroStatusTap;
  final VoidCallback? onComment;
  final VoidCallback? onLike;
  final bool isLiked;
  final int? likeCountOverride;

  @override
  Widget build(BuildContext context) {
    switch (data.type) {
      case FeedCardType.highlight:
        return _HighlightCard(
          data: data,
          onAuthorTap: onAuthorTap,
          onTap: onTap,
          onComment: onComment,
          onLike: onLike,
          isLiked: isLiked,
          likeCountOverride: likeCountOverride,
        );
      case FeedCardType.mission:
        return _MissionCard(
          data: data,
          onAuthorTap: onAuthorTap,
          onTap: onTap,
          onLike: onLike,
          isLiked: isLiked,
          likeCountOverride: likeCountOverride,
        );
      case FeedCardType.investor:
        return _InvestorCard(
          data: data,
          introPending: introPending,
          introStatus: introStatus,
          onIntroSent: onIntroSent,
          onAuthorTap: onAuthorTap,
          onIntroStatusTap: onIntroStatusTap,
          onTap: onTap,
          onComment: onComment,
          onLike: onLike,
          isLiked: isLiked,
          likeCountOverride: likeCountOverride,
        );
      case FeedCardType.update:
        return _UpdateCard(
          data: data,
          onAuthorTap: onAuthorTap,
          onTap: onTap,
          onComment: onComment,
          onLike: onLike,
          isLiked: isLiked,
          likeCountOverride: likeCountOverride,
        );
    }
  }
}

Widget _linkedCardShell(
  BuildContext context, {
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
  double radius = 14,
}) {
  final theme = Theme.of(context);
  final borderColor = theme.colorScheme.outlineVariant.withOpacity(0.45);

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    color: theme.colorScheme.surface,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    ),
    child: Padding(
      padding: padding,
      child: child,
    ),
  );
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard(
      {required this.data, this.onAuthorTap, this.onTap, this.onComment, this.onLike, this.isLiked = false, this.likeCountOverride});

  final FeedCardData data;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final VoidCallback? onComment;
  final VoidCallback? onLike;
  final bool isLiked;
  final int? likeCountOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);
    final likeCount = likeCountOverride ?? data.likeCount;
    final card = _linkedCardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(author: data.author, onTap: onAuthorTap),
          const SizedBox(height: 12),
          if (data.title.isNotEmpty) ...[
            Text(
              data.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            data.subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(height: 1.4, fontSize: 15),
          ),
          if (data.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (data.metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            MetricPills(metrics: data.metrics),
          ],
          if (data.ask != null) ...[
            const SizedBox(height: 10),
            _AskChip(label: data.ask!),
          ],
          const SizedBox(height: 14),
          _EngagementCounts(
            likeCount: likeCount,
            commentCount: data.commentCount,
            accent: accent,
          ),
          const Divider(height: 24),
          ActionBar(
            accent: accent,
            onComment: onComment,
            commentCount: data.commentCount,
            onLike: onLike,
            isLiked: isLiked,
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard(
      {required this.data, this.onAuthorTap, this.onTap, this.onComment, this.onLike, this.isLiked = false, this.likeCountOverride});

  final FeedCardData data;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final VoidCallback? onComment;
  final VoidCallback? onLike;
  final bool isLiked;
  final int? likeCountOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);
    final likeCount = likeCountOverride ?? data.likeCount;

    final card = _linkedCardShell(
      context,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(author: data.author, onTap: onAuthorTap),
          const SizedBox(height: 12),
          Text(
            data.title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            data.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          if (data.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.tags
                  .map(
                    (tag) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (data.ask != null) ...[
            const SizedBox(height: 10),
            _AskChip(label: data.ask!),
          ],
          if (data.metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            MetricPills(metrics: data.metrics),
          ],
          const SizedBox(height: 12),
          _EngagementCounts(
            likeCount: likeCount,
            commentCount: data.commentCount,
            accent: accent,
          ),
          const Divider(height: 24),
          ActionBar(
            accent: accent,
            onComment: onComment,
            commentCount: data.commentCount,
            onLike: onLike,
            isLiked: isLiked,
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.data,
    this.onAuthorTap,
    this.onTap,
    this.onLike,
    this.isLiked = false,
    this.likeCountOverride,
  });

  final FeedCardData data;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool isLiked;
  final int? likeCountOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);
    final likeCount = likeCountOverride ?? data.likeCount;

    final card = _linkedCardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(author: data.author, onTap: onAuthorTap),
          const SizedBox(height: 10),
          Text(
            data.title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  .map(
                    (tag) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _EngagementCounts(
            likeCount: likeCount,
            commentCount: data.commentCount,
            accent: accent,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mission claimed: ${data.title}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Claim'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          ActionBar(
            accent: accent,
            onComment: null,
            commentCount: data.commentCount,
            onLike: onLike,
            isLiked: isLiked,
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class _InvestorCard extends StatefulWidget {
  const _InvestorCard({
    required this.data,
    this.introPending = false,
    this.introStatus,
    this.onIntroSent,
    this.onAuthorTap,
    this.onTap,
    this.onIntroStatusTap,
    this.onComment,
    this.onLike,
    this.isLiked = false,
    this.likeCountOverride,
  });

  final FeedCardData data;
  final bool introPending;
  final ContactRequestStatus? introStatus;
  final VoidCallback? onIntroSent;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final VoidCallback? onIntroStatusTap;
  final VoidCallback? onComment;
  final VoidCallback? onLike;
  final bool isLiked;
  final int? likeCountOverride;

  @override
  State<_InvestorCard> createState() => _InvestorCardState();
}

class _InvestorCardState extends State<_InvestorCard> {
  bool _requesting = false;
  bool _introSent = false;

  @override
  void initState() {
    super.initState();
    _introSent = widget.introPending ||
        (widget.introStatus != null &&
            widget.introStatus != ContactRequestStatus.declined);
  }

  @override
  void didUpdateWidget(covariant _InvestorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasIntro = widget.introPending ||
        (widget.introStatus != null &&
            widget.introStatus != ContactRequestStatus.declined);
    if (hasIntro && !_introSent) {
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
    final likeCount = widget.likeCountOverride ?? data.likeCount;

    final card = _linkedCardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(author: data.author, onTap: widget.onAuthorTap),
          const SizedBox(height: 10),
          Text(
            data.title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  .map(
                    (tag) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        if (data.ask != null) ...[
          const SizedBox(height: 10),
          _AskChip(label: data.ask!),
        ],
        const SizedBox(height: 12),
        _EngagementCounts(
          likeCount: likeCount,
          commentCount: data.commentCount,
          accent: accent,
        ),
        const Divider(height: 24),
        Row(
          children: [
            if (!disabled) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleRequestIntro,
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
                      : const Text('Request intro'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton(
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
                child: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ActionBar(
          accent: accent,
          onComment: widget.onComment,
          commentCount: data.commentCount,
          onLike: widget.onLike,
            isLiked: widget.isLiked,
          ),
        ],
      ),
    );
    if (widget.onTap == null) return card;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: card,
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

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.author, this.onTap});

  final FeedAuthor author;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(author.role, theme);
    final initial = author.name.isNotEmpty ? author.name[0].toUpperCase() : '?';
    final subtitle = [
      if (author.affiliation.isNotEmpty) author.affiliation,
      if (author.timeAgo.isNotEmpty) author.timeAgo,
    ].join(' · ');

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: accent.withValues(alpha: 0.12),
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
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz),
          tooltip: 'More',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (context) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.volume_off),
                        title: const Text('Mute author'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Author muted (placeholder)')),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Report'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Report submitted (placeholder)')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
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
  const ActionBar({
    Key? key,
    required this.accent,
    this.onComment,
    this.commentCount,
    this.onLike,
    this.isLiked = false,
  }) : super(key: key);

  final Color accent;
  final VoidCallback? onComment;
  final int? commentCount;
  final VoidCallback? onLike;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurfaceVariant;
    final likeColor = isLiked ? accent : baseColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _ActionButton(
            icon: isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt_outlined,
            label: isLiked ? 'Liked' : 'Like',
            accent: likeColor,
            onTap: onLike,
            filled: isLiked,
          ),
        ),
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comment',
            accent: baseColor,
            onTap: () {
              if (onComment != null) {
                onComment!();
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comments coming soon')),
              );
            },
          ),
        ),
        Expanded(
          child: _ActionButton(
            icon: Icons.send_outlined,
            label: 'Send',
            accent: baseColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Shared via message')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = filled ? accent : theme.colorScheme.onSurfaceVariant;

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(
        icon,
        size: 18,
        color: color,
      ),
      label: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _EngagementCounts extends StatelessWidget {
  const _EngagementCounts({
    required this.likeCount,
    required this.commentCount,
    required this.accent,
  });

  final int likeCount;
  final int commentCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final commentLabel =
        '$commentCount comment${commentCount == 1 ? '' : 's'}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.thumb_up_alt, size: 14, color: accent),
            ),
            const SizedBox(width: 6),
            Text(
              likeCount.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              commentLabel,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1),
            ),
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

String _chipLabel(ContactRequestStatus? status) {
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

Color _chipColor(ContactRequestStatus? status, Color accent) {
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

class _RoleDetailChips extends StatelessWidget {
  const _RoleDetailChips({required this.role, required this.details});

  final String role;
  final Map<String, dynamic> details;

  @override
  Widget build(BuildContext context) {
    final r = role.toLowerCase();
    final chips = <Widget>[];

    if (r == 'investor') {
      final type = details['investor_type']?.toString();
      final ticket = details['ticket_size']?.toString();
      final stages =
          (details['stages'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (type != null && type.isNotEmpty) {
        chips.add(_chip(type));
      }
      if (ticket != null && ticket.isNotEmpty) {
        chips.add(_chip('Tickets: $ticket'));
      }
      if (stages.isNotEmpty) {
        chips.add(_chip('Stages: ${stages.join(', ')}'));
      }
    } else if (r == 'founder') {
      final stage = details['stage']?.toString();
      final startup = details['startup_name']?.toString();
      final looking =
          (details['looking_for'] as List?)?.map((e) => e.toString()).toList() ??
              [];
      if (startup != null && startup.isNotEmpty) chips.add(_chip(startup));
      if (stage != null && stage.isNotEmpty) chips.add(_chip('Stage: $stage'));
      if (looking.isNotEmpty) {
        chips.add(_chip('Looking: ${looking.join(', ')}'));
      }
    } else if (r == 'end-user' || r == 'enduser') {
      final roleMain = details['main_role']?.toString();
      final exp = details['experience_level']?.toString();
      final interests =
          (details['interests'] as List?)?.map((e) => e.toString()).toList() ??
              [];
      if (roleMain != null && roleMain.isNotEmpty) chips.add(_chip(roleMain));
      if (exp != null && exp.isNotEmpty) chips.add(_chip('Experience: $exp'));
      if (interests.isNotEmpty) {
        chips.add(_chip('Interests: ${interests.join(', ')}'));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
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
