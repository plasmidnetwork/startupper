import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/snackbar.dart';
import 'contact_request_models.dart';
import 'feed_service.dart';
import 'feed_models.dart';
import '../services/supabase_service.dart';

class ContactRequestsScreen extends StatefulWidget {
  const ContactRequestsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ContactRequestsScreen> createState() => _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends State<ContactRequestsScreen> {
  final _service = FeedService();
  final _profileService = SupabaseService();
  final Map<String, bool> _updating = {};
  final Map<String, bool> _updatingNotes = {};
  final Set<String> _introDisabled = {};
  final Set<ContactRequestStatus> _incomingFilters = {
    ContactRequestStatus.pending,
    ContactRequestStatus.accepted,
    ContactRequestStatus.declined,
  };
  final Set<ContactRequestStatus> _outgoingFilters = {
    ContactRequestStatus.pending,
    ContactRequestStatus.accepted,
    ContactRequestStatus.declined,
  };
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
        _introDisabled.addAll(
          data.where((r) => r.status != ContactRequestStatus.declined).map(
              (r) => r.requester.id == _userId ? r.target.id : r.requester.id),
        );
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
        _introDisabled.addAll(
          data
              .where((r) => r.status != ContactRequestStatus.declined)
              .map((r) => r.target.id),
        );
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
    if (!mounted) return;
    setState(() {
      _updating[request.id] = true;
    });
    final previousStatus = request.status;
    try {
      await _service.updateContactRequestStatus(id: request.id, status: status);
      await _loadIncoming();
      await _loadOutgoing();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final snack = SnackBar(
        content: Text('Status updated to ${status.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await _service.updateContactRequestStatus(
                  id: request.id, status: previousStatus);
              await _loadIncoming();
              await _loadOutgoing();
              if (mounted) {
                showSuccessSnackBar(
                    context, 'Reverted to ${previousStatus.name}');
              }
            } catch (_) {
              if (mounted) {
                showErrorSnackBar(context, 'Could not undo update.');
              }
            }
          },
        ),
      );
      messenger.showSnackBar(snack);
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

  Future<void> _editNotes(ContactRequest request) async {
    if (_updatingNotes[request.id] == true) return;
    final controller = TextEditingController(text: request.notes ?? '');
    final notes = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes (visible to both sides)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (notes == null) return;
    setState(() {
      _updatingNotes[request.id] = true;
    });
    try {
      await _service.updateContactRequestNotes(id: request.id, notes: notes);
      await _loadIncoming();
      await _loadOutgoing();
      if (mounted) {
        showSuccessSnackBar(context, 'Notes updated');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not update notes.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingNotes.remove(request.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connections')),
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
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connections'),
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
              onAccept: (req) =>
                  _updateStatus(req, ContactRequestStatus.accepted),
              onDecline: (req) =>
                  _updateStatus(req, ContactRequestStatus.declined),
              updating: _updating,
              isIncomingTab: true,
              onOpenFeedItem: _openFeedItem,
              onAuthorTap: _openAuthorSheet,
              statusFilters: _incomingFilters,
              onToggleStatus: (status) {
                setState(() {
                  if (_incomingFilters.contains(status)) {
                    _incomingFilters.remove(status);
                  } else {
                    _incomingFilters.add(status);
                  }
                });
              },
              onEditNotes: _editNotes,
              updatingNotes: _updatingNotes,
              onMessage: _openChat,
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
              onOpenFeedItem: _openFeedItem,
              onAuthorTap: _openAuthorSheet,
              statusFilters: _outgoingFilters,
              onToggleStatus: (status) {
                setState(() {
                  if (_outgoingFilters.contains(status)) {
                    _outgoingFilters.remove(status);
                  } else {
                    _outgoingFilters.add(status);
                  }
                });
              },
              onEditNotes: _editNotes,
              updatingNotes: _updatingNotes,
              onMessage: _openChat,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFeedItem(String feedItemId, [FeedCardData? initial]) async {
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/feed/item',
      arguments: {'id': feedItemId, 'data': initial},
    );
  }

  Future<void> _openChat(ContactRequest request, ContactRequestParty other) async {
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/intros/chat',
      arguments: {
        'introId': request.id,
        'other': other,
      },
    );
  }

  Future<void> _openAuthorSheet(ContactRequestParty party) async {
    if (!mounted) return;
    bool requesting = false;
    final detailsFuture = party.id.isNotEmpty
        ? _profileService.fetchRoleDetailsForUser(party.id, party.role)
        : Future.value(null);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final disabled = _introDisabled.contains(party.id);
            Future<void> sendIntro() async {
              if (requesting || party.id.isEmpty || disabled) return;
              final controller = TextEditingController();
              final msg = await showDialog<String?>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Connect with ${party.name}'),
                  content: TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, controller.text);
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              );
              if (msg == null) return;
              setSheetState(() => requesting = true);
              try {
                await _service.requestIntro(
                  targetUserId: party.id,
                  message: msg.trim().isEmpty ? null : msg.trim(),
                );
                if (!mounted) return;
                setState(() {
                  _introDisabled.add(party.id);
                });
                Navigator.pop(context);
                showSuccessSnackBar(context, 'Connection request sent');
              } catch (_) {
                if (mounted) {
                  showErrorSnackBar(
                      context, 'Could not send connection right now.');
                }
              } finally {
                setSheetState(() => requesting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: (party.avatarUrl != null &&
                                party.avatarUrl!.isNotEmpty)
                            ? NetworkImage(party.avatarUrl!)
                            : null,
                        child: (party.avatarUrl == null ||
                                party.avatarUrl!.isEmpty)
                            ? Text(
                                party.name.isNotEmpty
                                    ? party.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
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
                              party.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${party.role}${party.headline.isNotEmpty ? ' · ${party.headline}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text(party.role),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (party.headline.isNotEmpty)
                                  Chip(
                                    label: Text(party.headline),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<Map<String, dynamic>?>(
                              future: detailsFuture,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  );
                                }
                                final d = snap.data;
                                if (d == null) return const SizedBox.shrink();
                                return _RoleDetailChips(
                                    role: party.role, details: d);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: disabled
                              ? 'You already sent an intro to this member'
                              : '',
                          child: ElevatedButton(
                            onPressed:
                                (party.id.isEmpty || disabled || requesting)
                                    ? null
                                    : sendIntro,
                          child: requesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(disabled
                                  ? 'Request sent'
                                  : 'Connect'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
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
    required this.onOpenFeedItem,
    required this.onAuthorTap,
    required this.statusFilters,
    required this.onToggleStatus,
    this.onAccept,
    this.onDecline,
    required this.onEditNotes,
    required this.updatingNotes,
    required this.onMessage,
  });

  final List<ContactRequest> requests;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final String currentUserId;
  final Map<String, bool> updating;
  final bool isIncomingTab;
  final Future<void> Function(String feedItemId, [FeedCardData? initial])
      onOpenFeedItem;
  final void Function(ContactRequestParty) onAuthorTap;
  final Set<ContactRequestStatus> statusFilters;
  final void Function(ContactRequestStatus) onToggleStatus;
  final void Function(ContactRequest)? onAccept;
  final void Function(ContactRequest)? onDecline;
  final void Function(ContactRequest) onEditNotes;
  final Map<String, bool> updatingNotes;
  final void Function(ContactRequest, ContactRequestParty) onMessage;

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

    final filtered =
        requests.where((r) => statusFilters.contains(r.status)).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StatusFilters(
              selected: statusFilters,
              onToggle: onToggleStatus,
            );
          }
          final req = filtered[index - 1];
          final isIncoming = currentUserId == req.target.id;
          final other = isIncoming ? req.requester : req.target;
          final canAct = isIncomingTab &&
              isIncoming &&
              req.isPending &&
              onAccept != null &&
              onDecline != null;
          final isUpdating = updating[req.id] == true;
          final isUpdatingNotes = updatingNotes[req.id] == true;
          return _RequestCard(
            request: req,
            other: other,
            isIncoming: isIncoming,
            canAct: canAct,
            isUpdating: isUpdating,
            onAccept: canAct && onAccept != null ? () => onAccept!(req) : null,
            onDecline:
                canAct && onDecline != null ? () => onDecline!(req) : null,
            onOpenFeed: req.feedItemId == null
                ? null
                : () => onOpenFeedItem(req.feedItemId!, null),
            onAuthorTap: () {
              final party = isIncoming ? req.requester : req.target;
              onAuthorTap(party);
            },
            onEditNotes: () => onEditNotes(req),
            editingNotes: isUpdatingNotes,
            onMessage: () => onMessage(req, other),
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
    this.onOpenFeed,
    this.onAuthorTap,
    this.onEditNotes,
    this.editingNotes = false,
    this.onMessage,
  });

  final ContactRequest request;
  final ContactRequestParty other;
  final bool isIncoming;
  final bool canAct;
  final bool isUpdating;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onOpenFeed;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onEditNotes;
  final bool editingNotes;
  final VoidCallback? onMessage;

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
            InkWell(
              onTap: onAuthorTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    backgroundImage:
                        (other.avatarUrl != null && other.avatarUrl!.isNotEmpty)
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
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                              backgroundColor:
                                  statusColor.withValues(alpha: 0.14),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700),
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
            ),
            const SizedBox(height: 12),
            if (request.message != null && request.message!.isNotEmpty) ...[
              Text(
                request.message!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
            ],
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              Text(
                'Notes',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                request.notes!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Requested $timeAgo',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const Spacer(),
                if (request.feedItemId != null)
                  InkWell(
                    onTap: onOpenFeed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          request.feedItemTitle?.isNotEmpty == true
                              ? request.feedItemTitle!
                              : 'Via feed',
                          style: theme.textTheme.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: editingNotes ? null : onEditNotes,
                  icon: editingNotes
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_note_outlined),
                  label: const Text('Add note'),
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
            if (!canAct &&
                request.status == ContactRequestStatus.accepted &&
                onMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMessage,
                      icon:
                          const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message'),
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

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected, required this.onToggle});

  final Set<ContactRequestStatus> selected;
  final void Function(ContactRequestStatus) onToggle;

  @override
  Widget build(BuildContext context) {
    final options = ContactRequestStatus.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (s) => FilterChip(
              label: Text(s.name),
              selected: selected.contains(s),
              onSelected: (_) => onToggle(s),
            ),
          )
          .toList(),
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

class _RoleDetailChips extends StatelessWidget {
  const _RoleDetailChips({required this.role, required this.details});

  final String role;
  final Map<String, dynamic> details;

  @override
  Widget build(BuildContext context) {
    final r = role.toLowerCase();
    final chips = <Widget>[];

    if (r == 'investor') {
      final type = details['investor_type']?.toString();
      final ticket = details['ticket_size']?.toString();
      final stages =
          (details['stages'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (type != null && type.isNotEmpty) chips.add(_chip(type));
      if (ticket != null && ticket.isNotEmpty) {
        chips.add(_chip('Tickets: $ticket'));
      }
      if (stages.isNotEmpty) {
        chips.add(_chip('Stages: ${stages.join(', ')}'));
      }
    } else if (r == 'founder') {
      final stage = details['stage']?.toString();
      final startup = details['startup_name']?.toString();
      final looking = (details['looking_for'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (startup != null && startup.isNotEmpty) chips.add(_chip(startup));
      if (stage != null && stage.isNotEmpty) chips.add(_chip('Stage: $stage'));
      if (looking.isNotEmpty) {
        chips.add(_chip('Looking: ${looking.join(', ')}'));
      }
    } else if (r == 'end-user' || r == 'enduser') {
      final roleMain = details['main_role']?.toString();
      final exp = details['experience_level']?.toString();
      final interests =
          (details['interests'] as List?)?.map((e) => e.toString()).toList() ??
              [];
      if (roleMain != null && roleMain.isNotEmpty) chips.add(_chip(roleMain));
      if (exp != null && exp.isNotEmpty) chips.add(_chip('Experience: $exp'));
      if (interests.isNotEmpty) {
        chips.add(_chip('Interests: ${interests.join(', ')}'));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
