class StartupProfile {
  const StartupProfile({
    required this.startupId,
    required this.userId,
    required this.founderName,
    required this.headline,
    required this.startupName,
    required this.pitch,
    required this.stage,
    required this.lookingFor,
    required this.location,
    required this.createdAt,
    this.avatarUrl,
    this.founderAvatarUrl,
    this.website,
    this.demoVideo,
    this.appStoreId,
    this.playStoreId,
  });

  final String startupId;
  final String userId;
  final String founderName;
  final String headline;
  final String startupName;
  final String pitch;
  final String stage;
  final List<String> lookingFor;
  final String location;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? founderAvatarUrl;
  final String? website;
  final String? demoVideo;
  final String? appStoreId;
  final String? playStoreId;
}

class StartupPage {
  const StartupPage({required this.items, required this.hasMore});

  final List<StartupProfile> items;
  final bool hasMore;
}
