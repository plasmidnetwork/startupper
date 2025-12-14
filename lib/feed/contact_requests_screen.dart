import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/snackbar.dart';
import 'contact_request_models.dart';
import 'feed_service.dart';

class ContactRequestsScreen extends StatefulWidget {
  const ContactRequestsScreen({super.key});

  @override
  State<ContactRequestsScreen> createState() => _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends State<ContactRequestsScreen> {
  final _service = FeedService();
  final Map<String, bool> _updating = {};
  List<ContactRequest> _incoming = [];
  List<ContactRequest> _outgoing = [];
  bool _loadingIncoming = true;
  bool _loadingOutgoing = true;
  String? _errorIncoming;
  String? _errorOutgoing;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadIncoming(), _loadOutgoing()]);
  }

  Future<void> _loadIncoming() async {
    setState(() {
      _loadingIncoming = true;
      _errorIncoming = null;
    });
    try {
      final data = await _service.fetchContactRequests(outgoing: false);
      if (!mounted) return;
      setState(() {
        _incoming = data;
        _loadingIncoming = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingIncoming = false;
        _errorIncoming = 'Could not load incoming intros.';
      });
    }
  }

  Future<void> _loadOutgoing() async {
    setState(() {
      _loadingOutgoing = true;
      _errorOutgoing = null;
    });
    try {
      final data = await _service.fetchContactRequests(outgoing: true);
      if (!mounted) return;
      setState(() {
        _outgoing = data;
        _loadingOutgoing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOutgoing = false;
        _errorOutgoing = 'Could not load sent intros.';
      });
    }
  }

  Future<void> _updateStatus(
    ContactRequest request,
    ContactRequestStatus status,
  ) async {
    if (_updating[request.id] == true) return;
    setState(() {
      _updating[request.id] = true;
    });
    try {
      await _service.updateContactRequestStatus(id: request.id, status: status);
      await _loadIncoming();
      await _loadOutgoing();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Status updated');
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not update request.');
    } finally {
      if (mounted) {
        setState(() {
          _updating.remove(request.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Intros')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Sign in to view intro requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Intros'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestList(
              requests: _incoming,
              loading: _loadingIncoming,
              error: _errorIncoming,
              onRefresh: _loadIncoming,
              currentUserId: _userId!,
              onAccept: (req) => _updateStatus(req, ContactRequestStatus.accepted),
              onDecline: (req) => _updateStatus(req, ContactRequestStatus.declined),
              updating: _updating,
              isIncomingTab: true,
            ),
            _RequestList(
              requests: _outgoing,
              loading: _loadingOutgoing,
              error: _errorOutgoing,
              onRefresh: _loadOutgoing,
              currentUserId: _userId!,
              onAccept: null,
              onDecline: null,
              updating: _updating,
              isIncomingTab: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.currentUserId,
    required this.updating,
    required this.isIncomingTab,
    this.onAccept,
    this.onDecline,
  });

  final List<ContactRequest> requests;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final String currentUserId;
  final Map<String, bool> updating;
  final bool isIncomingTab;
  final void Function(ContactRequest)? onAccept;
  final void Function(ContactRequest)? onDecline;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('No intro requests yet'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = requests[index];
          final isIncoming = currentUserId == req.target.id;
          final other = isIncoming ? req.requester : req.target;
          final canAct =
              isIncomingTab && isIncoming && req.isPending && onAccept != null && onDecline != null;
          final isUpdating = updating[req.id] == true;
          return _RequestCard(
            request: req,
            other: other,
            isIncoming: isIncoming,
            canAct: canAct,
            isUpdating: isUpdating,
            onAccept: canAct && onAccept != null ? () => onAccept!(req) : null,
            onDecline: canAct && onDecline != null ? () => onDecline!(req) : null,
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.other,
    required this.isIncoming,
    required this.canAct,
    required this.isUpdating,
    this.onAccept,
    this.onDecline,
  });

  final ContactRequest request;
  final ContactRequestParty other;
  final bool isIncoming;
  final bool canAct;
  final bool isUpdating;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _roleAccent(other.role, theme);
    final initial = other.name.isNotEmpty ? other.name[0].toUpperCase() : '?';
    final statusLabel = request.status.name;
    final statusColor = _statusColor(request.status, theme);
    final timeAgo = _timeAgo(request.createdAt);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  backgroundImage: (other.avatarUrl != null && other.avatarUrl!.isNotEmpty)
                      ? NetworkImage(other.avatarUrl!)
                      : null,
                  child: (other.avatarUrl == null || other.avatarUrl!.isEmpty)
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${other.role}${other.headline.isNotEmpty ? ' · ${other.headline}' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(statusLabel),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: statusColor.withValues(alpha: 0.14),
                            labelStyle: theme.textTheme.labelMedium
                                ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            isIncoming ? 'Incoming' : 'Sent',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (request.message != null && request.message!.isNotEmpty) ...[
              Text(
                request.message!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Requested $timeAgo',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const Spacer(),
                if (request.feedItemId != null)
                  Text(
                    'Via feed',
                    style: theme.textTheme.labelMedium,
                  ),
              ],
            ),
            if (canAct) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isUpdating ? null : onDecline,
                      child: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isUpdating ? null : onAccept,
                      child: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _statusColor(ContactRequestStatus status, ThemeData theme) {
  switch (status) {
    case ContactRequestStatus.accepted:
      return Colors.green;
    case ContactRequestStatus.declined:
      return theme.colorScheme.error;
    case ContactRequestStatus.pending:
    default:
      return theme.colorScheme.primary;
  }
}

Color _roleAccent(String role, ThemeData theme) {
  switch (role.toLowerCase()) {
    case 'founder':
      return Colors.blueAccent;
    case 'investor':
      return Colors.green;
    case 'builder':
    case 'end-user':
      return Colors.orange;
    default:
      return theme.colorScheme.primary;
  }
}

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
