import 'dart:async';
import 'package:flutter/material.dart';
import 'feed_models.dart';

class FeedRepository {
  // Simulate initial fetch with slight delay.
  Future<List<FeedCardData>> fetchFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mockFeed;
  }

  // Simulate loading more items; cycles through the mock list.
  Future<List<FeedCardData>> loadMore(int currentCount) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final start = currentCount % _mockFeed.length;
    final next = _mockFeed.sublist(start) + _mockFeed.sublist(0, start);
    // Return only a handful to mimic pagination.
    return next.take(3).toList();
  }
}

const _mockFeed = <FeedCardData>[
  FeedCardData(
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
      MetricHighlight(label: 'Engagement', value: '5.2 min', color: Colors.redAccent),
    ],
  ),
  FeedCardData(
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
    type: FeedCardType.mission,
    author: FeedAuthor(
      name: 'Priya Nair',
      role: 'Founder',
      affiliation: 'Orbitly',
      timeAgo: '2d',
    ),
    title: 'User interviews (fintech operators)',
    subtitle: 'Need 3 quick calls to vet a workflow idea. I\'ll compensate for time.',
    tags: ['Research', '30 min', 'Remote'],
    reward: '\$75',
    ask: 'Fintech ops / PMs preferred',
  ),
  FeedCardData(
    type: FeedCardType.investor,
    author: FeedAuthor(
      name: 'Chen Wu',
      role: 'Investor',
      affiliation: 'Parallel Capital',
      timeAgo: '3d',
    ),
    title: 'Parallel Capital — SaaS infra & AI tooling',
    subtitle: 'Writing \$250k–\$600k checks; focused on workflow AI with clear unit economics.',
    tags: ['Seed', 'Infra', 'AI tooling'],
    ask: 'Booking office hours next week',
  ),
  FeedCardData(
    type: FeedCardType.update,
    author: FeedAuthor(
      name: 'Jade Ellis',
      role: 'Founder',
      affiliation: 'Tandem Labs',
      timeAgo: '3d',
    ),
    title: 'Beta shipped to 40 teams',
    subtitle: 'Hit 40 design partner teams; NPS 62. Starting to price next month.',
    ask: 'Looking for pricing advisor',
    metrics: [
      MetricHighlight(label: 'DAU', value: '1.4k'),
      MetricHighlight(label: 'NPS', value: '62', color: Colors.green),
    ],
  ),
  FeedCardData(
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
