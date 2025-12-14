import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_models.dart';
import 'contact_request_models.dart';

class FeedService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createFeedItem({
    required FeedCardType type,
    required String title,
    required String subtitle,
    String? ask,
    List<String>? tags,
    List<MetricHighlight>? metrics,
    String? reward,
    bool featured = false,
    String? userRoleTag,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not signed in');
    }

    final content = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'ask': ask,
      'tags': {
        ...?tags?.toSet(),
        if (userRoleTag != null && userRoleTag.isNotEmpty) userRoleTag,
      }.toList(),
      'reward': reward,
      'featured': featured,
      'metrics': (metrics ?? [])
          .map((m) => {'label': m.label, 'value': m.value})
          .toList(),
    };

    await _client.from('feed_items').insert({
      'type': type.name,
      'content': content,
      'user_id': userId,
    });
  }

  Future<void> requestIntro({
    required String targetUserId,
    String? feedItemId,
    String? message,
  }) async {
    final requester = _client.auth.currentUser?.id;
    if (requester == null) {
      throw StateError('User not signed in');
    }

    await _client.from('contact_requests').insert({
      'requester': requester,
      'target': targetUserId,
      if (feedItemId != null) 'feed_item_id': feedItemId,
      if (message != null && message.isNotEmpty) 'message': message,
      'status': 'pending',
    });
  }

  Future<List<ContactRequest>> fetchContactRequests({
    required bool outgoing,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not signed in');
    }

    final filterColumn = outgoing ? 'requester' : 'target';
    final List<dynamic> rows = await _client
        .from('contact_requests')
        .select('id, status, message, feed_item_id, created_at, '
            'notes, feed_item:feed_items(id, content), '
            'requester:profiles!contact_requests_requester_fkey(id, full_name, role, headline, avatar_url), '
            'target:profiles!contact_requests_target_fkey(id, full_name, role, headline, avatar_url)')
        .eq(filterColumn, userId)
        .order('created_at', ascending: false);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(_mapContactRequest)
        .whereType<ContactRequest>()
        .toList();
  }

  Future<void> updateContactRequestStatus({
    required String id,
    required ContactRequestStatus status,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not signed in');
    }

    await _client.from('contact_requests').update({
      'status': status.name,
      'status_changed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> updateContactRequestNotes({
    required String id,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User not signed in');
    }
    await _client.from('contact_requests').update({
      'notes': notes ?? '',
    }).eq('id', id);
  }

  ContactRequest? _mapContactRequest(Map<String, dynamic> row) {
    final requesterJson = row['requester'] as Map?;
    final targetJson = row['target'] as Map?;
    if (requesterJson == null || targetJson == null) return null;

    final feedItemJson = row['feed_item'] as Map?;
    String? feedItemTitle;
    if (feedItemJson != null) {
      final content = feedItemJson['content'] as Map?;
      feedItemTitle = content?['title']?.toString();
    }

    final requester = ContactRequestParty(
      id: requesterJson['id']?.toString() ?? '',
      name: requesterJson['full_name']?.toString() ?? 'Member',
      role: requesterJson['role']?.toString() ?? 'Member',
      headline: requesterJson['headline']?.toString() ?? '',
      avatarUrl: requesterJson['avatar_url']?.toString(),
    );

    final target = ContactRequestParty(
      id: targetJson['id']?.toString() ?? '',
      name: targetJson['full_name']?.toString() ?? 'Member',
      role: targetJson['role']?.toString() ?? 'Member',
      headline: targetJson['headline']?.toString() ?? '',
      avatarUrl: targetJson['avatar_url']?.toString(),
    );

    final createdAtStr = row['created_at']?.toString();
    final createdAt = DateTime.tryParse(createdAtStr ?? '') ?? DateTime.now();

    final statusStr = row['status']?.toString() ?? 'pending';
    final status = statusFromString(statusStr);

    return ContactRequest(
      id: row['id']?.toString() ?? '',
      requester: requester,
      target: target,
      status: status,
      createdAt: createdAt,
      message: row['message']?.toString(),
      feedItemId: row['feed_item_id']?.toString(),
      feedItemTitle: feedItemTitle,
      notes: row['notes']?.toString(),
    );
  }
}
