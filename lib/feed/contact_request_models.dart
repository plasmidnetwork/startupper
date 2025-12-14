enum ContactRequestStatus { pending, accepted, declined }

ContactRequestStatus statusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'accepted':
      return ContactRequestStatus.accepted;
    case 'declined':
      return ContactRequestStatus.declined;
    case 'pending':
    default:
      return ContactRequestStatus.pending;
  }
}

class ContactRequestParty {
  const ContactRequestParty({
    required this.id,
    required this.name,
    required this.role,
    required this.headline,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final String headline;
  final String? avatarUrl;
}

class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.requester,
    required this.target,
    required this.status,
    required this.createdAt,
    this.message,
    this.feedItemId,
  });

  final String id;
  final ContactRequestParty requester;
  final ContactRequestParty target;
  final ContactRequestStatus status;
  final DateTime createdAt;
  final String? message;
  final String? feedItemId;

  bool get isPending => status == ContactRequestStatus.pending;
}
