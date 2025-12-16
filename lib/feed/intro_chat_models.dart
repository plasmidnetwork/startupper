class IntroMessage {
  const IntroMessage({
    required this.id,
    required this.introId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String introId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}
