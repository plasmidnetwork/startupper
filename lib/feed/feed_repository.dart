import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_models.dart';

class FeedPage {
  final List<FeedCardData> items;
  final bool hasMore;

  const FeedPage({required this.items, required this.hasMore});
}

class FeedRepository {
  final _client = Supabase.instance.client;
  final Map<String, FeedCardData> _cache = {};

  Future<FeedPage> fetchFeed({
    int offset = 0,
    int limit = 10,
    String? search,
    List<String>? tags,
    List<FeedCardType>? types,
  }) async {
    try {
      final query = _client.from('feed_items').select(
          // Include avatar_url so we can display user profile images
          'id, content, type, created_at, user:profiles(id, full_name, headline, role, avatar_url)');

      if (tags != null && tags.isNotEmpty) {
        query.contains('content->tags', tags);
      }

      if (types != null && types.isNotEmpty) {
        query.inFilter('type', types.map((t) => t.name).toList());
      }

      final trimmedSearch = search?.trim() ?? '';
      if (trimmedSearch.isNotEmpty) {
        final term = '%$trimmedSearch%';
        query.or(
            'content->>title.ilike.$term,content->>subtitle.ilike.$term,content->>ask.ilike.$term');
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      developer.log('FeedRepository.fetchFeed: fetched ${rows.length} rows',
          name: 'feed');

      final items = rows
          .map<FeedCardData?>((row) => _mapRow(row))
          .whereType<FeedCardData>()
          .toList();
      final hasMore = rows.length == limit;
      return FeedPage(items: items, hasMore: hasMore);
    } catch (_) {
      rethrow;
    }
  }

  Future<FeedPage> loadMore(
    int currentCount, {
    int limit = 10,
    String? search,
    List<String>? tags,
    List<FeedCardType>? types,
  }) {
    return fetchFeed(
      offset: currentCount,
      limit: limit,
      search: search,
      tags: tags,
      types: types,
    );
  }

  FeedCardData? _mapRow(Map<String, dynamic> row) {
    final content = (row['content'] as Map<String, dynamic>?);
    if (content == null) return null;
    final user = row['user'] as Map<String, dynamic>? ?? {};
    final createdAt = row['created_at'] as String?;

    final type = _typeFrom(row['type'] as String? ?? 'update');
    final tags = (content['tags'] as List?)?.cast<String>() ?? const [];
    final metricsJson = (content['metrics'] as List?) ?? [];
    final metrics = metricsJson
        .whereType<Map>()
        .map((m) => MetricHighlight(
              label: m['label']?.toString() ?? '',
              value: m['value']?.toString() ?? '',
            ))
        .toList();

    final authorId = user['id']?.toString();
    final authorName = user['full_name']?.toString();
    final authorRole = user['role']?.toString() ?? '';
    final authorAffiliation = user['headline']?.toString() ?? '';
    final avatarUrl = user['avatar_url']?.toString();
    final timeAgo = _formatTimeAgo(createdAt);

    // Debug logging for avatar troubleshooting
    developer.log(
      'FeedRepository._mapRow: author=$authorName, avatarUrl=$avatarUrl',
      name: 'feed',
    );

    final feedId = row['id']?.toString() ?? '';

    return FeedCardData(
      id: feedId,
      type: type,
      author: FeedAuthor(
        id: authorId,
        name: authorName?.isNotEmpty == true ? authorName! : 'Member',
        role: authorRole.isNotEmpty ? authorRole : 'Member',
        affiliation: authorAffiliation,
        timeAgo: timeAgo,
        avatarUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
      ),
      title: content['title']?.toString() ?? 'Update',
      subtitle: content['subtitle']?.toString() ?? '',
      ask: content['ask']?.toString(),
      metrics: metrics,
      tags: tags,
      reward: content['reward']?.toString(),
      featured: (content['featured'] as bool?) ?? false,
    );
  }

  FeedCardType _typeFrom(String type) {
    switch (type) {
      case 'highlight':
        return FeedCardType.highlight;
      case 'mission':
        return FeedCardType.mission;
      case 'investor':
        return FeedCardType.investor;
      case 'update':
      default:
        return FeedCardType.update;
    }
  }

  String _formatTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  Future<FeedCardData?> fetchById(String id) async {
    if (_cache.containsKey(id)) return _cache[id];
    try {
      final rows = await _client
          .from('feed_items')
          .select(
              'id, content, type, created_at, user:profiles(id, full_name, headline, role, avatar_url)')
          .eq('id', id)
          .limit(1);
      if (rows is List && rows.isNotEmpty) {
        final mapped = _mapRow(rows.first as Map<String, dynamic>);
        if (mapped != null) _cache[id] = mapped;
        return mapped;
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }

  void clearCache() => _cache.clear();
}

// ignore: unused_element
const _mockFeed = <FeedCardData>[
  FeedCardData(
    id: 'mock1',
    type: FeedCardType.highlight,
    author: FeedAuthor(
      name: 'Lina Park',
      role: 'Founder',
      affiliation: 'Northwind AI',
      timeAgo: '2h',
    ),
    title: 'Northwind AI',
    subtitle: 'Compliance co-pilot for seed-stage fintech teams.',
    tags: ['Seed', 'Fintech', 'B2B SaaS'],
    ask: 'Raising \$1.2M seed',
    metrics: [
      MetricHighlight(label: 'MRR', value: '+12%', color: Colors.blueAccent),
      MetricHighlight(label: 'Waitlist', value: '1.2k'),
    ],
    featured: true,
  ),
  FeedCardData(
    id: 'mock2',
    type: FeedCardType.update,
    author: FeedAuthor(
      name: 'Amir Khan',
      role: 'Founder',
      affiliation: 'Driftspace',
      timeAgo: '6h',
    ),
    title: 'Weekly update',
    subtitle:
        'Shipped AI onboarding and cut churn by 9%. Piloting with 3 design partners this week.',
    ask: 'Looking for intros to PLG advisors',
    metrics: [
      MetricHighlight(label: 'Activation', value: '+7%'),
      MetricHighlight(
          label: 'Engagement', value: '5.2 min', color: Colors.redAccent),
    ],
  ),
  FeedCardData(
    id: 'mock3',
    type: FeedCardType.mission,
    author: FeedAuthor(
      name: 'Sofia Duarte',
      role: 'Founder',
      affiliation: 'Velvet Labs',
      timeAgo: '8h',
    ),
    title: 'Landing page UX teardown',
    subtitle: 'Need a sharp UX eye to tighten fold messaging and CTA flow.',
    tags: ['Design', '1-2 hrs', 'Remote'],
    reward: '\$300',
    ask: 'Prefer B2B SaaS experience',
  ),
  FeedCardData(
    id: 'mock4',
    type: FeedCardType.highlight,
    author: FeedAuthor(
      name: 'Kai Müller',
      role: 'Founder',
      affiliation: 'Sunset Bio',
      timeAgo: '1d',
    ),
    title: 'Sunset Bio',
    subtitle: 'Home-to-clinic lab kit routing with insurer integrations.',
    tags: ['Health', 'Series A', 'APIs'],
    ask: 'Adding design partners',
    metrics: [
      MetricHighlight(label: 'Clinics', value: '42'),
      MetricHighlight(label: 'Turnaround', value: '-18%', color: Colors.green),
    ],
    featured: true,
  ),
  FeedCardData(
    id: 'mock5',
    type: FeedCardType.investor,
    author: FeedAuthor(
      name: 'Amelia Cho',
      role: 'Investor',
      affiliation: 'Peak Signal',
      timeAgo: '1d',
    ),
    title: 'Peak Signal — B2B infra & applied AI',
    subtitle:
        'Leading \$150k–\$500k checks, post-revenue. Looking for workflow AI with strong gross margin.',
    tags: ['Seed', 'AI infra', 'Vertical SaaS'],
    ask: 'Office hours this week',
  ),
  FeedCardData(
    id: 'mock6',
    type: FeedCardType.update,
    author: FeedAuthor(
      name: 'Diego Rojas',
      role: 'Builder',
      affiliation: 'UX engineer',
      timeAgo: '2d',
    ),
    title: 'Shipped design sprint',
    subtitle:
        'Wrapped a 4-day sprint for a fintech dashboard. Happy to help founders with quick front-end lifts.',
    ask: 'Open for weekend missions',
    metrics: [
      MetricHighlight(label: 'CSAT', value: '9.4/10', color: Colors.orange),
    ],
  ),
  FeedCardData(
    id: 'mock7',
    type: FeedCardType.mission,
    author: FeedAuthor(
      name: 'Priya Nair',
      role: 'Founder',
      affiliation: 'Orbitly',
      timeAgo: '2d',
    ),
    title: 'User interviews (fintech operators)',
    subtitle:
        'Need 3 quick calls to vet a workflow idea. I\'ll compensate for time.',
    tags: ['Research', '30 min', 'Remote'],
    reward: '\$75',
    ask: 'Fintech ops / PMs preferred',
  ),
  FeedCardData(
    id: 'mock8',
    type: FeedCardType.investor,
    author: FeedAuthor(
      name: 'Chen Wu',
      role: 'Investor',
      affiliation: 'Parallel Capital',
      timeAgo: '3d',
    ),
    title: 'Parallel Capital — SaaS infra & AI tooling',
    subtitle:
        'Writing \$250k–\$600k checks; focused on workflow AI with clear unit economics.',
    tags: ['Seed', 'Infra', 'AI tooling'],
    ask: 'Booking office hours next week',
  ),
  FeedCardData(
    id: 'mock9',
    type: FeedCardType.update,
    author: FeedAuthor(
      name: 'Jade Ellis',
      role: 'Founder',
      affiliation: 'Tandem Labs',
      timeAgo: '3d',
    ),
    title: 'Beta shipped to 40 teams',
    subtitle:
        'Hit 40 design partner teams; NPS 62. Starting to price next month.',
    ask: 'Looking for pricing advisor',
    metrics: [
      MetricHighlight(label: 'DAU', value: '1.4k'),
      MetricHighlight(label: 'NPS', value: '62', color: Colors.green),
    ],
  ),
  FeedCardData(
    id: 'mock10',
    type: FeedCardType.highlight,
    author: FeedAuthor(
      name: 'Marcos Silva',
      role: 'Founder',
      affiliation: 'Harbor',
      timeAgo: '4d',
    ),
    title: 'Harbor',
    subtitle: 'Compliance automation for shipping and logistics teams.',
    tags: ['Logistics', 'B2B SaaS', 'Seed'],
    ask: 'Seeking design partners',
    metrics: [
      MetricHighlight(label: 'Pilots', value: '9'),
      MetricHighlight(label: 'Time saved', value: '-22%', color: Colors.green),
    ],
    featured: true,
  ),
];
