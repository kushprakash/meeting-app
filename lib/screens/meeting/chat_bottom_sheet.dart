import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/livekit_room_provider.dart';

class ChatBottomSheet extends StatefulWidget {
  const ChatBottomSheet({super.key});

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final room = Provider.of<LiveKitRoomProvider>(context, listen: false);
    room.sendChatMessage(text);
    _textController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<LiveKitRoomProvider>(context);
    final messages = room.chatMessages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.bgDarkBody,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppTheme.accentColor),
                const SizedBox(width: 10),
                const Text(
                  'In-Meeting Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          // Chat list
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Send a message to chat!',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = messages[idx];
                      final timeStr = DateFormat('hh:mm a').format(msg.timestamp);

                      return Align(
                        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isMe
                                ? AppTheme.primaryColor
                                : (msg.isHost ? AppTheme.cardDark : AppTheme.surfaceDark),
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(16),
                              bottomLeft: !msg.isMe ? const Radius.circular(0) : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!msg.isMe) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg.senderName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: msg.isHost ? AppTheme.warning : AppTheme.accentColor,
                                      ),
                                    ),
                                    if (msg.isHost) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star, size: 12, color: AppTheme.warning),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                msg.message,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Input bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type message...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
