import 'package:flutter/material.dart';

enum FeedCardType { update, highlight, mission, investor }

class FeedAuthor {
  const FeedAuthor({
    required this.name,
    required this.role,
    required this.affiliation,
    required this.location,
    required this.timeAgo,
    this.id,
    this.avatarUrl,
  });

  final String? id;
  final String name;
  final String role;
  final String affiliation;
  final String location;
  final String timeAgo;
  final String? avatarUrl;
}

class FeedMedia {
  const FeedMedia({required this.url, required this.type});

  final String url; // public URL to the media
  final String type; // 'image' or 'video'
}

class FeedMediaUpload {
  const FeedMediaUpload.bytes({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.isVideo,
  }) : file = null;

  const FeedMediaUpload.file({
    required this.file,
    required this.isVideo,
  })  : bytes = null,
        filename = null,
        contentType = null;

  final List<int>? bytes;
  final String? filename;
  final String? contentType;
  final Object? file; // File on mobile/desktop; null on web
  final bool isVideo;
}

class MetricHighlight {
  const MetricHighlight({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;
}

class FeedCardData {
  const FeedCardData({
    required this.id,
    required this.type,
    required this.author,
    required this.title,
    required this.subtitle,
    this.ask,
    this.metrics = const [],
    this.tags = const [],
    this.reward,
    this.featured = false,
    this.commentCount = 0,
    this.likeCount = 0,
    this.repostCount = 0,
    this.media = const [],
  });

  final FeedCardType type;
  final FeedAuthor author;
  final String id;
  final String title;
  final String subtitle;
  final String? ask;
  final List<MetricHighlight> metrics;
  final List<String> tags;
  final String? reward;
  final bool featured;
  final int commentCount;
  final int likeCount;
  final int repostCount;
  final List<FeedMedia> media;
}
