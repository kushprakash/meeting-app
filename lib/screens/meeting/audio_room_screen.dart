import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../models/participant.dart';
import '../../providers/livekit_room_provider.dart';
import '../../widgets/audio_avatar.dart';
import '../../widgets/status_badge.dart';
import 'chat_bottom_sheet.dart';
import 'host_controls_dialog.dart';
import 'participant_requests_dialog.dart';

class AudioRoomScreen extends StatefulWidget {
  const AudioRoomScreen({super.key});

  @override
  State<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends State<AudioRoomScreen> {
  bool _isLeaving = false;

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

  void _confirmLeave(BuildContext context, LiveKitRoomProvider room) async {
    if (_isLeaving) return; // Prevent double-tap

    final nav = Navigator.of(context);

    // Show confirmation dialog
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Leave Meeting?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to leave this audio room?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLeave != true) return;
    if (!mounted) return;

    setState(() => _isLeaving = true);

    await room.leaveRoom();

    if (mounted && nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<LiveKitRoomProvider>(context);
    final meeting = room.meeting;
    final currentUser = room.currentUser;
    final participants = room.meetingParticipants;
    final pendingRequests = room.pendingRequests;

    // Auto exit ONLY when host explicitly removes/kicks participant or meeting ends
    if (room.errorMessage != null && room.errorMessage!.isNotEmpty && !_isLeaving) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          final msg = room.errorMessage!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg)),
                ],
              ),
              backgroundColor: AppTheme.warning,
            ),
          );
          Navigator.of(context).pop();
        }
      });
    }

    return PopScope(
      canPop: _isLeaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isLeaving) {
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
            if (meeting != null)
              IconButton(
                icon: const Icon(Icons.share, color: AppTheme.accentColor),
                tooltip: 'Share Meeting Code',
                onPressed: () {
                  final text = 'Join my Audio Meeting on MeetInt!\n\nTitle: ${meeting.title}\nMeeting Code: ${meeting.uuid}\n\nJoin link: https://vidbez.com/meeting/${meeting.uuid}';
                  Share.share(text, subject: 'Join Meeting: ${meeting.title}');
                },
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
            // Real-time Pending Join Requests Banner for Host
            if (room.isHost && pendingRequests.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.7), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_sharp, color: Colors.black, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pendingRequests.length} Join Request${pendingRequests.length > 1 ? "s" : ""} Pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Latest: ${pendingRequests.last.user?.name ?? pendingRequests.last.email}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openPendingRequests(context),
                      child: const Text(
                        'Review',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            // Participants Grid (excluding current user to prevent duplicate avatars)
            Expanded(
              child: Builder(
                builder: (context) {
                  final otherParticipants = participants.where((p) =>
                    p.userId != currentUser?.id &&
                    (currentUser == null || p.email.toLowerCase() != currentUser.email.toLowerCase())
                  ).toList();

                  // Ensure Host avatar is ALWAYS first (Index 0) among remote participants
                  final hostEmail = meeting?.host?.email.toLowerCase() ?? '';
                  final hostId = meeting?.hostId ?? 0;

                  int hostIdx = otherParticipants.indexWhere((p) =>
                    p.role == 'host' ||
                    (hostId != 0 && p.userId == hostId) ||
                    (hostEmail.isNotEmpty && p.email.toLowerCase() == hostEmail)
                  );

                  if (hostIdx > 0) {
                    final hostP = otherParticipants.removeAt(hostIdx);
                    otherParticipants.insert(0, hostP);
                  } else if (hostIdx == -1 && !room.isHost && meeting?.host != null) {
                    otherParticipants.insert(0, ParticipantModel(
                      id: meeting!.hostId,
                      meetingId: meeting!.id,
                      userId: meeting!.hostId,
                      email: meeting!.host!.email,
                      role: 'host',
                      status: 'joined',
                      user: meeting!.host,
                    ));
                  }

                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: otherParticipants.length + 1, // +1 for current user
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

                        final p = otherParticipants[idx - 1];
                        final isHostUser = p.role == 'host' || (meeting != null && p.userId == meeting.hostId);
                        final isMuted = room.isParticipantMuted(p.email, userEmail: p.user?.email);

                        return AudioAvatar(
                          name: p.user?.name ?? (p.email.contains('@') ? p.email.split('@')[0] : p.email),
                          isHost: isHostUser,
                          isMuted: isMuted,
                          isSpeaking: !isMuted,
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
                  );
                },
              ),
            ),
            // Floating Control Bar with SafeArea protection for mobile navigation bar
            SafeArea(
              top: false,
              bottom: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
            ),
          ],
        ),
      ),
    );
  }
}
