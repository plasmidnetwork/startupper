import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_models.dart';
import 'feed_repository.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Set<String> _activeFilters = {'Personalized'};
  final _repo = FeedRepository();
  final ScrollController _scrollController = ScrollController();
  List<FeedCardData> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchFeed();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = 'Could not load feed. Pull to retry.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchFeed();
      if (!mounted) return;
      setState(() {
        _items = data;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = 'Could not refresh feed. Pull to retry.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final more = await _repo.loadMore(_items.length);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...more];
        _loadingMore = false;
      });
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = _items.where((item) => item.featured).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        automaticallyImplyLeading: false,
        actions: [
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
      body: SafeArea(
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
                        },
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
                if (featured.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 250,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) => _FeaturedCard(
                            data: featured[index],
                          ),
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemCount: featured.length,
                        ),
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _items[index];
                      return Padding(
                        padding:
                            EdgeInsets.fromLTRB(16, index == 0 ? 16 : 12, 16, 4),
                        child: FeedCard(data: item),
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
                          : Text(
                              _refreshing ? 'Refreshing...' : ' ',
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
    );
  }
}

class FeedCard extends StatelessWidget {
  const FeedCard({Key? key, required this.data}) : super(key: key);

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    switch (data.type) {
      case FeedCardType.highlight:
        return _HighlightCard(data: data);
      case FeedCardType.mission:
        return _MissionCard(data: data);
      case FeedCardType.investor:
        return _InvestorCard(data: data);
      case FeedCardType.update:
      default:
        return _UpdateCard(data: data);
    }
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.data});

  final FeedCardData data;

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
            AvatarNameRow(author: data.author),
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
  const _HighlightCard({required this.data});

  final FeedCardData data;

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
            constraints: const BoxConstraints(minHeight: 96),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.18), accent.withOpacity(0.05)],
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
                              backgroundColor:
                                  Colors.white.withOpacity(0.85),
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
                AvatarNameRow(author: data.author),
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
  const _MissionCard({required this.data});

  final FeedCardData data;

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
                Expanded(child: AvatarNameRow(author: data.author)),
                if (data.reward != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.reward!,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: accent, fontWeight: FontWeight.w600),
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
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
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

class _InvestorCard extends StatelessWidget {
  const _InvestorCard({required this.data});

  final FeedCardData data;

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
            AvatarNameRow(author: data.author),
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
                          backgroundColor: accent.withOpacity(0.12),
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
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Intro requested with ${data.author.name}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Request intro'),
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
  const AvatarNameRow({Key? key, required this.author}) : super(key: key);

  final FeedAuthor author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(author.role, theme);
    final initial = author.name.isNotEmpty ? author.name[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: accent.withOpacity(0.16),
          child: Text(
            initial,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                color: metric.color?.withOpacity(0.12) ??
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

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.data});

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(data.author.role, theme);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.16), accent.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.16)),
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
                      backgroundColor: Colors.white.withOpacity(0.9),
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
        color: theme.colorScheme.primary.withOpacity(0.08),
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
  });

  final Set<String> activeFilters;
  final void Function(String) onToggle;

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
      children: filters
          .map(
            (filter) => FilterChip(
              label: Text(filter),
              selected: activeFilters.contains(filter),
              onSelected: (_) => onToggle(filter),
            ),
          )
          .toList(),
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
    final base = Theme.of(context).colorScheme.surfaceVariant;
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
        color: base.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _chip(Color base, {required double width}) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: base.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
