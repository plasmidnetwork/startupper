import 'package:flutter/material.dart';
import 'feed_models.dart';
import 'feed_repository.dart';
import 'feed_screen.dart';
import '../theme/loading_overlay.dart';
import '../theme/snackbar.dart';
import 'feed_service.dart';
import 'package:flutter/services.dart';
import '../app_config.dart';
import 'contact_request_models.dart';

class FeedItemScreen extends StatefulWidget {
  const FeedItemScreen({
    super.key,
    required this.id,
    this.initial,
  });

  final String id;
  final FeedCardData? initial;

  @override
  State<FeedItemScreen> createState() => _FeedItemScreenState();
}

class _FeedItemScreenState extends State<FeedItemScreen> {
  final _repo = FeedRepository();
  final _service = FeedService();
  FeedCardData? _data;
  bool _loading = true;
  String? _error;
  bool _sendingIntro = false;
  bool _introSent = false;
  ContactRequestStatus? _introStatus;
  String? _copiedLink;
  ContactRequest? _introRequest;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    if (_data != null) {
      _loading = false;
      _loadIntroStatus();
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _repo.fetchById(widget.id);
      if (!mounted) return;
      setState(() {
        _data = item;
        _loading = false;
        if (item == null) {
          _error = 'This feed item is not available.';
        }
      });
      if (item != null) {
        _loadIntroStatus();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this feed item.';
      });
    }
  }

  Future<void> _loadIntroStatus() async {
    final authorId = _data?.author.id;
    if (authorId == null || authorId.isEmpty) return;
    try {
      final sent = await _service.fetchContactRequests(outgoing: true);
      if (!mounted) return;
      final matchList = sent.where((r) => r.target.id == authorId).toList();
      if (matchList.isNotEmpty) {
        final match = matchList.first;
        setState(() {
          _introStatus = match.status;
          _introRequest = match;
          _introSent = match.status != ContactRequestStatus.declined;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Intros',
            onPressed: () {
              Navigator.pushNamed(context, '/intros',
                  arguments: {'initialTab': 1});
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Copy link',
            onSelected: (choice) {
              _copyLink(choice == 'web');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'app',
                child: Text('Copy app link'),
              ),
              const PopupMenuItem(
                value: 'web',
                child: Text('Copy web link'),
              ),
            ],
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading && _data == null,
        message: 'Loading...',
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _fetch,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _data == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FeedCard(data: _data!),
                        const SizedBox(height: 16),
                        _Actions(
                          data: _data!,
                          introSent: _introSent,
                          sendingIntro: _sendingIntro,
                          onRequestIntro: _handleRequestIntro,
                          onOpenProfile: _openProfileSheet,
                          onCopyLink: _copyLink,
                          copiedLink: _copiedLink,
                          introStatus: _introStatus,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _handleRequestIntro() async {
    if (_sendingIntro || _introSent) return;
    final authorId = _data?.author.id;
    if (authorId == null || authorId.isEmpty) {
      showErrorSnackBar(context, 'Missing member profile for intro.');
      return;
    }
    setState(() => _sendingIntro = true);
    try {
      await _service.requestIntro(
        targetUserId: authorId,
        feedItemId: _data?.id,
      );
      if (!mounted) return;
      setState(() {
        _introSent = true;
      });
      showSuccessSnackBar(context, 'Intro request sent');
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not send intro right now.');
    } finally {
      if (mounted) {
        setState(() => _sendingIntro = false);
      }
    }
  }

  Future<void> _openProfileSheet() async {
    final author = _data?.author;
    if (author == null) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final accent = _roleAccent(author.role, theme);
        final initial =
            author.name.isNotEmpty ? author.name[0].toUpperCase() : '?';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: accent.withValues(alpha: 0.16),
                    backgroundImage: (author.avatarUrl != null &&
                            author.avatarUrl!.isNotEmpty)
                        ? NetworkImage(author.avatarUrl!)
                        : null,
                    child:
                        (author.avatarUrl == null || author.avatarUrl!.isEmpty)
                            ? Text(
                                initial,
                                style: TextStyle(
                                  color: accent,
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
                          author.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${author.role}${author.affiliation.isNotEmpty ? ' · ${author.affiliation}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyLink([bool useWeb = false]) async {
    final rawBase = useWeb && kFeedWebLinkBase.isNotEmpty
        ? kFeedWebLinkBase
        : kFeedLinkBase;
    if (useWeb && kFeedWebLinkBase.isEmpty && mounted) {
      showErrorSnackBar(
        context,
        'Web link base not set. Set FEED_WEB_LINK_BASE or copy app link instead.',
      );
    }
    final base = rawBase.endsWith('/') ? rawBase : '$rawBase/';
    final link = '$base${widget.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      setState(() {
        _copiedLink = link;
      });
      showSuccessSnackBar(context, 'Link copied');
    }
  }
}

String _chipLabel(ContactRequestStatus? status) {
  switch (status) {
    case ContactRequestStatus.accepted:
      return 'Intro accepted';
    case ContactRequestStatus.declined:
      return 'Intro declined';
    case ContactRequestStatus.pending:
    case null:
      return 'Intro sent';
  }
}

Color _introChipColor(ContactRequestStatus? status, ThemeData theme) {
  switch (status) {
    case ContactRequestStatus.accepted:
      return Colors.green.withValues(alpha: 0.14);
    case ContactRequestStatus.declined:
      return theme.colorScheme.error.withValues(alpha: 0.14);
    case ContactRequestStatus.pending:
    case null:
      return theme.colorScheme.primary.withValues(alpha: 0.14);
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.data,
    required this.introSent,
    required this.sendingIntro,
    required this.onRequestIntro,
    required this.onOpenProfile,
    required this.onCopyLink,
    this.copiedLink,
    this.introStatus,
    this.introRequest,
  });

  final FeedCardData data;
  final bool introSent;
  final bool sendingIntro;
  final VoidCallback onRequestIntro;
  final VoidCallback onOpenProfile;
  final VoidCallback onCopyLink;
  final String? copiedLink;
  final ContactRequestStatus? introStatus;
  final ContactRequest? introRequest;

  @override
  Widget build(BuildContext context) {
    final isInvestor = data.type == FeedCardType.investor;
    final canIntro =
        isInvestor && data.author.id != null && data.author.id!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onOpenProfile,
          child: const Text('Open profile'),
        ),
        if (canIntro) ...[
          const SizedBox(height: 8),
          if (introSent)
            Tooltip(
              message: _chipLabel(introStatus),
              child: Chip(
                label: Text(_chipLabel(introStatus)),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    _introChipColor(introStatus, Theme.of(context)),
              ),
            )
          else
            ElevatedButton(
              onPressed: sendingIntro ? null : onRequestIntro,
              child: sendingIntro
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Request intro'),
            ),
        ],
      ],
    );
  }
}

/// Returns an accent color based on the user's role.
/// This helper maps role strings to specific colors for visual distinction.
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
