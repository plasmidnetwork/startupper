import 'package:flutter/material.dart';

enum FeedCardType { update, highlight, mission, investor }

class FeedAuthor {
  const FeedAuthor({
    required this.name,
    required this.role,
    required this.affiliation,
    required this.timeAgo,
    this.avatarUrl,
  });

  final String name;
  final String role;
  final String affiliation;
  final String timeAgo;
  final String? avatarUrl;
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
    required this.type,
    required this.author,
    required this.title,
    required this.subtitle,
    this.ask,
    this.metrics = const [],
    this.tags = const [],
    this.reward,
    this.featured = false,
  });

  final FeedCardType type;
  final FeedAuthor author;
  final String title;
  final String subtitle;
  final String? ask;
  final List<MetricHighlight> metrics;
  final List<String> tags;
  final String? reward;
  final bool featured;
}
