import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_service.dart';
import 'intro_chat_models.dart';
import 'contact_request_models.dart';

class IntroChatScreen extends StatefulWidget {
  const IntroChatScreen({
    Key? key,
    required this.introId,
    required this.other,
  }) : super(key: key);

  final String introId;
  final ContactRequestParty other;

  @override
  State<IntroChatScreen> createState() => _IntroChatScreenState();
}

class _IntroChatScreenState extends State<IntroChatScreen> {
  final _service = FeedService();
  final _textController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendIntroMessage(introId: widget.introId, body: text);
      _textController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.other.name}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<IntroMessage>>(
              stream: _service.streamIntroMessages(widget.introId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load messages'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final align =
                        m.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                    final bubbleColor = m.isMine
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                        : Theme.of(context).colorScheme.surfaceVariant;
                    final textColor = m.isMine
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).textTheme.bodyMedium?.color;
                    return Column(
                      crossAxisAlignment: align,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: align,
                            children: [
                              Text(
                                m.body,
                                style: TextStyle(color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(m.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
