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
import 'comment_models.dart';

class FeedItemScreen extends StatefulWidget {
  const FeedItemScreen({
    super.key,
    required this.id,
    this.initial,
    this.focusComments = false,
    this.initialIntroStatus,
    this.initialIntroPending = false,
    this.initialIsLiked = false,
    this.initialLikeCount,
  });

  final String id;
  final FeedCardData? initial;
  final bool focusComments;
  final ContactRequestStatus? initialIntroStatus;
  final bool initialIntroPending;
  final bool initialIsLiked;
  final int? initialLikeCount;

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
  bool _isLiked = false;
  int? _likeOverride;
  List<FeedComment> _comments = [];
  bool _commentsLoading = true;
  String? _commentsError;
  bool _postingComment = false;
  final Map<String, bool> _deletingComment = {};
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _shouldFocusComment = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    _shouldFocusComment = widget.focusComments;
    _introStatus = widget.initialIntroStatus;
    _introSent = widget.initialIntroPending ||
        (widget.initialIntroStatus != null &&
            widget.initialIntroStatus != ContactRequestStatus.declined);
    _isLiked = widget.initialIsLiked;
    _likeOverride = widget.initialLikeCount;
    if (_data != null) {
      _loading = false;
      _loadIntroStatus();
      _loadComments();
    } else {
      _fetch();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
        } else {
          _likeOverride ??= item.likeCount;
        }
      });
      if (item != null) {
        _loadIntroStatus();
        _loadComments();
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

  Future<void> _handleLike() async {
    if (_data == null) return;
    final id = _data!.id;
    final currentlyLiked = _isLiked;
    final currentCount = _likeOverride ?? _data!.likeCount;
    setState(() {
      _isLiked = !currentlyLiked;
      _likeOverride =
          currentlyLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1;
    });
    try {
      if (currentlyLiked) {
        await _service.unlikeFeedItem(id);
      } else {
        await _service.likeFeedItem(id);
      }
    } catch (_) {
      setState(() {
        _isLiked = currentlyLiked;
        _likeOverride = currentCount;
      });
      if (mounted) {
        showErrorSnackBar(context, 'Could not update like right now.');
      }
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final items = await _service.fetchComments(widget.id);
      if (!mounted) return;
      setState(() {
        _comments = items;
        _commentsLoading = false;
      });
      if (_shouldFocusComment && mounted) {
        _commentFocusNode.requestFocus();
        _shouldFocusComment = false;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
        _commentsError = 'Could not load comments.';
      });
    }
  }

  Future<void> _postComment() async {
    if (_postingComment) return;
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      await _service.addComment(feedItemId: widget.id, body: text);
      _commentCtrl.clear();
      await _loadComments();
      if (mounted && _data != null) {
        setState(() {
          _data = FeedCardData(
            id: _data!.id,
            type: _data!.type,
            author: _data!.author,
            title: _data!.title,
            subtitle: _data!.subtitle,
            ask: _data!.ask,
            metrics: _data!.metrics,
            tags: _data!.tags,
            reward: _data!.reward,
            featured: _data!.featured,
            commentCount: _data!.commentCount + 1,
            likeCount: _likeOverride ?? _data!.likeCount,
            repostCount: _data!.repostCount,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not post comment.');
      }
    } finally {
      if (mounted) {
        setState(() => _postingComment = false);
      }
    }
  }

  Future<void> _deleteComment(FeedComment comment) async {
    if (_deletingComment[comment.id] == true) return;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete comment?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    setState(() {
      _deletingComment[comment.id] = true;
    });
    try {
      await _service.deleteComment(comment.id);
      await _loadComments();
      if (mounted && _data != null && _data!.commentCount > 0) {
        setState(() {
          _data = FeedCardData(
            id: _data!.id,
            type: _data!.type,
            author: _data!.author,
            title: _data!.title,
            subtitle: _data!.subtitle,
            ask: _data!.ask,
            metrics: _data!.metrics,
            tags: _data!.tags,
            reward: _data!.reward,
            featured: _data!.featured,
            commentCount: _data!.commentCount - 1,
            likeCount: _likeOverride ?? _data!.likeCount,
            repostCount: _data!.repostCount,
          );
        });
      }
      if (mounted) {
        showSuccessSnackBar(context, 'Comment deleted');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not delete comment.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingComment.remove(comment.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popResult = _data == null
        ? null
        : {
            'id': _data!.id,
            'commentCount': _data!.commentCount,
            'likeCount': _likeOverride ?? _data!.likeCount,
            'isLiked': _isLiked,
          };

    return WillPopScope(
      onWillPop: () async {
        if (popResult != null) {
          Navigator.pop(context, popResult);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (popResult != null) {
                Navigator.pop(context, popResult);
              } else {
                Navigator.pop(context);
              }
            },
          ),
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
                          FeedCard(
                            data: _data!,
                            introPending:
                                _introStatus == ContactRequestStatus.pending,
                            introStatus: _introStatus,
                            onAuthorTap: _openProfileSheet,
                            onLike: _handleLike,
                            isLiked: _isLiked,
                            likeCountOverride: _likeOverride,
                            onComment: () {
                              _commentFocusNode.requestFocus();
                            },
                            // Comment count badge stays in sync with data snapshot
                          ),
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
                          const SizedBox(height: 16),
                          _CommentsSection(
                            comments: _comments,
                            loading: _commentsLoading,
                            error: _commentsError,
                            onRetry: _loadComments,
                            onSubmit: _postComment,
                            controller: _commentCtrl,
                            focusNode: _commentFocusNode,
                            posting: _postingComment,
                            deleting: _deletingComment,
                            onDelete: _deleteComment,
                          ),
                        ],
                      ),
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
        if (canIntro && !introSent) ...[
          const SizedBox(height: 8),
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

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSubmit,
    required this.controller,
    required this.focusNode,
    required this.posting,
    required this.deleting,
    required this.onDelete,
  });

  final List<FeedComment> comments;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSubmit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool posting;
  final Map<String, bool> deleting;
  final void Function(FeedComment) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comments',
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload comments',
              onPressed: loading ? null : onRetry,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !posting,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: 'Add a comment...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: posting ? null : onSubmit,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          Column(
            children: [
              Text(
                error!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          )
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Be the first to comment.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final comment = comments[index];
              final deletingComment = deleting[comment.id] == true;
              final initial =
                  comment.author.name.isNotEmpty ? comment.author.name[0].toUpperCase() : '?';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: (comment.author.avatarUrl != null &&
                            comment.author.avatarUrl!.isNotEmpty)
                        ? NetworkImage(comment.author.avatarUrl!)
                        : null,
                    child: (comment.author.avatarUrl == null ||
                            comment.author.avatarUrl!.isEmpty)
                        ? Text(
                            initial,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.author.name,
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              _timeAgo(comment.createdAt),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                            if (comment.isMine)
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: deletingComment
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.delete_outline, size: 18),
                                onPressed:
                                    deletingComment ? null : () => onDelete(comment),
                                tooltip: 'Delete',
                              ),
                          ],
                        ),
                        Text(
                          comment.body,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: comments.length,
          ),
      ],
    );
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

String _timeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
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
