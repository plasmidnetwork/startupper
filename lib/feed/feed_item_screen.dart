import 'package:flutter/material.dart';
import 'feed_models.dart';
import 'feed_repository.dart';
import 'feed_screen.dart';
import '../theme/loading_overlay.dart';
import '../theme/snackbar.dart';

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
  FeedCardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    if (_data != null) {
      _loading = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this feed item.';
      });
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
                    child: FeedCard(data: _data!),
                  ),
      ),
    );
  }
}
