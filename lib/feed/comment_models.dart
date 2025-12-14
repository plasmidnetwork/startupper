class FeedCommentAuthor {
  const FeedCommentAuthor({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.feedItemId,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.isMine,
  });

  final String id;
  final String feedItemId;
  final String body;
  final DateTime createdAt;
  final FeedCommentAuthor author;
  final bool isMine;
}
