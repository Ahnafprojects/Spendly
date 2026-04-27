import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/chat_database.dart';
import '../chat_notifier.dart';
import '../chat_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  static const _suggestions = [
    'Pengeluaran bulan ini',
    'Kategori terbesar',
    'Cari transaksi',
    'Tips hemat',
  ];

  static const _firstActions = [
    'Ringkasan Bulan Ini',
    'Cari Transaksi',
    'Tips Hemat',
    'Prediksi Pengeluaran',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80;
    if (_showScrollToBottom == !atBottom) return;
    setState(() => _showScrollToBottom = !atBottom);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatNotifierProvider, (_, next) {
      if (next.hasValue) {
        _scrollToBottom();
      }
    });

    final state = ref.watch(chatNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12D18E),
                      shape: BoxShape.circle,
                      border: Border.all(color: bg, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Text('Spendly AI'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'new') {
                await ref.read(chatNotifierProvider.notifier).startNewChat();
              } else if (value == 'clear') {
                await ref
                    .read(chatNotifierProvider.notifier)
                    .clearCurrentChat();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('Chat baru')),
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: const Color(0xFF4F6EF7),
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            )
          : null,
      body: state.when(
        data: (chat) {
          return Stack(
            children: [
              const Positioned.fill(child: _DotPattern()),
              Column(
                children: [
                  if (chat.messages.length <= 1 && chat.sessions.length > 1)
                    _PreviousSessions(
                      sessions: chat.sessions
                          .where((s) => s.id != chat.activeSessionId)
                          .toList(),
                      onTap: (sessionId) async {
                        await ref
                            .read(chatNotifierProvider.notifier)
                            .openSession(sessionId);
                      },
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      itemCount: chat.messages.length + (chat.isTyping ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (chat.isTyping && index == chat.messages.length) {
                          return const _TypingBubble();
                        }
                        final message = chat.messages[index];
                        final previous = index > 0
                            ? chat.messages[index - 1]
                            : null;
                        final showTimestamp =
                            previous == null ||
                            message.createdAt
                                    .difference(previous.createdAt)
                                    .inMinutes >
                                5;
                        return Column(
                          children: [
                            if (showTimestamp)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _formatTimestamp(message.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            _MessageBubble(message: message),
                          ],
                        );
                      },
                    ),
                  ),
                  if (chat.messages.length <= 1)
                    _QuickActions(onTap: _useSuggestion),
                  if (chat.error != null) _ChatError(text: chat.error!),
                  if (chat.suggestedFollowUps.isNotEmpty)
                    _FollowUpSuggestions(
                      items: chat.suggestedFollowUps,
                      onTap: (text) => _submit(text),
                    ),
                  _InputArea(
                    controller: _controller,
                    onSend: _submit,
                    suggestions: chat.messages.length <= 1
                        ? _suggestions
                        : const [],
                    onSuggestionTap: _useSuggestion,
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _useSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _submit([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(chatNotifierProvider.notifier).sendMessage(text);
  }
}

class _PreviousSessions extends StatelessWidget {
  final List<ChatSession> sessions;
  final ValueChanged<String> onTap;

  const _PreviousSessions({required this.sessions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          ...sessions
              .take(6)
              .map(
                (session) => GestureDetector(
                  onTap: () => onTap(session.id),
                  child: Container(
                    width: 188,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141420),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Percakapan Sebelumnya',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const actions = _ChatScreenState._firstActions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (action) => ActionChip(
                onPressed: () => onTap(action),
                backgroundColor: const Color(0xFF141420),
                side: const BorderSide(color: Colors.white10),
                label: Text(
                  action,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function([String? preset]) onSend;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const _InputArea({
    required this.controller,
    required this.onSend,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => onSuggestionTap(suggestions[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141420),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        suggestions[index],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (suggestions.isNotEmpty) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF141420),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const IconButton(
                    onPressed: null,
                    icon: Icon(Icons.mic_none_rounded, color: Colors.white24),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Tanya soal keuanganmu...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, __) {
                      final enabled = value.text.trim().isNotEmpty;
                      return IconButton(
                        onPressed: enabled ? () => onSend() : null,
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF4F6EF7), Color(0xFF6B3FE7)],
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final meta = ChatMessageMeta.decode(message.metadataJson);
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 52 : 0,
        right: isUser ? 0 : 52,
        bottom: 10,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF4F6EF7), Color(0xFF6B3FE7)],
                          )
                        : null,
                    color: isUser ? null : const Color(0xFF1C1C2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (!isUser && meta.sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meta.sources
                        .map((item) => _SourceChip(label: item))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpSuggestions extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;

  const _FollowUpSuggestions({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        itemBuilder: (_, index) => GestureDetector(
          onTap: () => onTap(items[index]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF171A29),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF2A3150)),
            ),
            alignment: Alignment.center,
            child: Text(
              items[index],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;

  const _SourceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF101523),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF28314A)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 52, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final progress = (_controller.value - (index * 0.18)).clamp(
                      0.0,
                      1.0,
                    );
                    final dy = progress < 0.5
                        ? progress * 4
                        : (1 - progress) * 4;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.translate(
                        offset: Offset(0, -dy),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  final String text;

  const _ChatError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF3A1520),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x66FF5A6E)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _DotPatternPainter()));
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x14FFFFFF);
    const gap = 24.0;
    for (double y = 0; y < size.height; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x + 2, y + 2), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatTimestamp(DateTime dateTime) {
  final h = dateTime.hour.toString().padLeft(2, '0');
  final m = dateTime.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
