import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/livekit_room_provider.dart';
import '../../widgets/audio_avatar.dart';
import '../../widgets/status_badge.dart';
import 'chat_bottom_sheet.dart';
import 'host_controls_dialog.dart';
import 'participant_requests_dialog.dart';

class AudioRoomScreen extends StatelessWidget {
  const AudioRoomScreen({super.key});

  void _copyMeetingId(BuildContext context, String uuid) {
    Clipboard.setData(ClipboardData(text: uuid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meeting Code copied to clipboard!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatBottomSheet(),
    );
  }

  void _openPendingRequests(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ParticipantRequestsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<LiveKitRoomProvider>(context);
    final meeting = room.meeting;
    final currentUser = room.currentUser;
    final participants = room.meetingParticipants;
    final pendingRequests = room.pendingRequests;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          _confirmLeave(context, room);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting?.title ?? 'Audio Room',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meeting != null)
                      GestureDetector(
                        onTap: () => _copyMeetingId(context, meeting.uuid),
                        child: Row(
                          children: [
                            Text(
                              'Code: ${meeting.uuid.substring(0, 8)}...',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 10, color: AppTheme.accentColor),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (meeting != null)
                StatusBadge(
                  text: meeting.visibility.toUpperCase(),
                  color: meeting.isPrivate ? AppTheme.warning : AppTheme.success,
                ),
            ],
          ),
          actions: [
            // Host pending approval badge
            if (room.isHost)
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined, color: AppTheme.accentColor),
                    tooltip: 'Join Requests',
                    onPressed: () => _openPendingRequests(context),
                  ),
                  if (pendingRequests.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${pendingRequests.length}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              tooltip: 'Leave Room',
              onPressed: () => _confirmLeave(context, room),
            ),
          ],
        ),
        body: Column(
          children: [
            // Active room status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.bgDarkHeader,
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: AppTheme.accentColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    room.isMuted ? 'Microphone Muted' : 'Live Audio Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: room.isMuted ? Colors.redAccent : AppTheme.accentColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${participants.length + 1} Connected',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            // Participants Grid
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: participants.length + 1, // +1 for current user
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      // Current User Avatar
                      return AudioAvatar(
                        name: '${currentUser?.name ?? "Me"} (You)',
                        isHost: room.isHost,
                        isMuted: room.isMuted,
                        isSpeaking: !room.isMuted,
                        radius: 36,
                      );
                    }

                    final p = participants[idx - 1];
                    final isHostUser = p.role == 'host' || (meeting != null && p.userId == meeting.hostId);

                    return AudioAvatar(
                      name: p.user?.name ?? p.email.split('@')[0],
                      isHost: isHostUser,
                      isMuted: true, // Synced via events
                      isSpeaking: false,
                      radius: 36,
                      onTap: () {
                        if (room.isHost && p.user?.id != currentUser?.id) {
                          showDialog(
                            context: context,
                            builder: (_) => HostControlsDialog(participant: p),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            // Floating Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic Toggle Button
                  GestureDetector(
                    onTap: () => room.toggleMicrophone(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: room.isMuted ? Colors.red.withValues(alpha: 0.2) : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: room.isMuted ? Colors.red : AppTheme.primaryLight,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        room.isMuted ? Icons.mic_off : Icons.mic,
                        size: 28,
                        color: room.isMuted ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                  // Chat Button
                  GestureDetector(
                    onTap: () => _openChat(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Stack(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 28, color: Colors.white),
                          if (room.chatMessages.isNotEmpty)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Leave Button
                  GestureDetector(
                    onTap: () => _confirmLeave(context, room),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, size: 28, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, LiveKitRoomProvider room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Leave Audio Room?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disconnect from this audio room?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await room.leaveRoom();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
