import 'package:supabase_flutter/supabase_flutter.dart';
import 'startup_models.dart';

class StartupRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<StartupPage> fetchStartups({
    int offset = 0,
    int limit = 10,
    String? search,
    List<String>? stages,
    List<String>? lookingFor,
  }) async {
    try {
      final query = _client.from('founder_details').select(
          'user_id, startup_name, pitch, stage, looking_for, website, demo_video, app_store_id, play_store_id, created_at, profile:profiles!inner(id, full_name, headline, location, avatar_url, role)');

      query.eq('profile.role', 'Founder');

      final trimmedSearch = search?.trim() ?? '';
      if (trimmedSearch.isNotEmpty) {
        final term = '%$trimmedSearch%';
        query.or('startup_name.ilike.$term,pitch.ilike.$term');
      }

      if (stages != null && stages.isNotEmpty) {
        query.inFilter('stage', stages);
      }

      if (lookingFor != null && lookingFor.isNotEmpty) {
        query.contains('looking_for', lookingFor);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final items = rows
          .whereType<Map<String, dynamic>>()
          .map(_mapRow)
          .whereType<StartupProfile>()
          .toList();
      final hasMore = rows.length == limit;
      return StartupPage(items: items, hasMore: hasMore);
    } catch (_) {
      rethrow;
    }
  }

  Future<StartupPage> loadMore(
    int currentCount, {
    int limit = 10,
    String? search,
    List<String>? stages,
    List<String>? lookingFor,
  }) {
    return fetchStartups(
      offset: currentCount,
      limit: limit,
      search: search,
      stages: stages,
      lookingFor: lookingFor,
    );
  }

  StartupProfile? _mapRow(Map<String, dynamic> row) {
    final profile = row['profile'] as Map?;
    if (profile == null) return null;

    final looking =
        (row['looking_for'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final createdAtStr = row['created_at']?.toString();
    final createdAt = DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();

    return StartupProfile(
      userId: profile['id']?.toString() ?? '',
      founderName: profile['full_name']?.toString() ?? 'Founder',
      headline: profile['headline']?.toString() ?? '',
      startupName: row['startup_name']?.toString() ?? 'Startup',
      pitch: row['pitch']?.toString() ?? '',
      stage: row['stage']?.toString() ?? '',
      lookingFor: looking,
      location: profile['location']?.toString() ?? '',
      createdAt: createdAt,
      avatarUrl: profile['avatar_url']?.toString(),
      website: row['website']?.toString(),
      demoVideo: row['demo_video']?.toString(),
      appStoreId: row['app_store_id']?.toString(),
      playStoreId: row['play_store_id']?.toString(),
    );
  }
}
