import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livekit_room_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';
import '../meeting/audio_room_screen.dart';
import 'create_meeting_screen.dart';

import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<MeetingProvider>(context, listen: false).fetchMeetings();
      _checkPendingMeeting();
    });
  }

  void _checkPendingMeeting() async {
    final pendingUuid = await ApiService.getPendingMeetingUuid();
    if (pendingUuid != null && pendingUuid.isNotEmpty) {
      await ApiService.removePendingMeetingUuid();
      _performJoin(pendingUuid);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _onJoinMeeting(MeetingModel meeting) async {
    if (meeting.isMeetingExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This meeting has expired and cannot be joined.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    _performJoin(meeting.uuid);
  }

  void _onJoinByCodeDialog() {
    _joinCodeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Join Meeting', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Meeting UUID or Code:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _joinCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _joinCodeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _performJoin(code);
              }
            },
            child: const Text('Join Room'),
          ),
        ],
      ),
    );
  }

  void _performJoin(String uuid, [Map<String, dynamic>? preFetchedData]) async {
    final meetingProvider = Provider.of<MeetingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final livekitRoom = Provider.of<LiveKitRoomProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentColor),
      ),
    );

    try {
      final res = preFetchedData != null
          ? {'status': 'success', 'data': preFetchedData}
          : await meetingProvider.joinMeeting(uuid);

      if (!mounted) return;

      if (res['status'] == 'success' && res['data']?['access'] == 'granted') {
        final data = res['data'];
        final token = data['token'];
        final livekitHost = data['livekit_host'] ?? 'http://127.0.0.1:7880';
        final role = data['role'] ?? 'participant';

        MeetingModel meeting = MeetingModel(
          id: 0,
          uuid: uuid,
          title: 'Audio Room',
          hostId: 0,
          visibility: 'public',
          approvalRequired: false,
          status: 'active',
          allowAudio: true,
          allowVideo: false,
          allowScreenShare: false,
          allowChat: true,
        );

        if (meetingProvider.hostedMeetings.any((m) => m.uuid == uuid)) {
          meeting = meetingProvider.hostedMeetings.firstWhere((m) => m.uuid == uuid);
        } else if (meetingProvider.participatingMeetings.any((m) => m.uuid == uuid)) {
          meeting = meetingProvider.participatingMeetings.firstWhere((m) => m.uuid == uuid);
        }

        await livekitRoom.connectToRoom(
          meeting: meeting,
          currentUser: authProvider.user!,
          token: token,
          livekitHost: livekitHost,
          role: role,
        );

        if (!mounted) return;
        Navigator.pop(context); // Close loader

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AudioRoomScreen()),
        );
      } else if (res['status'] == 'pending') {
        Navigator.pop(context); // Close loader
        _showWaitingApprovalDialog(uuid);
      } else {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Unable to join meeting'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showWaitingApprovalDialog(String uuid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WaitingApprovalDialog(
        uuid: uuid,
        onApproved: (targetUuid, data) {
          _performJoin(targetUuid, data);
        },
        onRejected: (errorMsg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Request Rejected: $errorMsg')),
                ],
              ),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        },
      ),
    );
  }

  void _showMeetingReportDialog(BuildContext context, MeetingModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assessment_outlined, color: AppTheme.accentColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Attendance & Meeting Report',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text(
              m.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Code (UUID): ${m.uuid}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Host:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Text(m.host?.name ?? 'Host User', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(m.host?.email ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const StatusBadge(
                    text: 'EXPIRED',
                    color: AppTheme.error,
                    icon: Icons.timer_off,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Participants History (${m.participants.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: m.participants.isEmpty
                  ? const Center(
                      child: Text(
                        'No participants recorded in this session',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: m.participants.length,
                      itemBuilder: (context, index) {
                        final p = m.participants[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: p.isHost ? AppTheme.warning : AppTheme.primaryColor,
                                child: Text(
                                  (p.user?.name ?? p.email).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.user?.name ?? 'Guest User',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      p.email,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                text: p.role.toUpperCase(),
                                color: p.isHost ? AppTheme.warning : AppTheme.info,
                              ),
                              const SizedBox(width: 6),
                              StatusBadge(
                                text: p.status.toUpperCase(),
                                color: p.isApproved ? AppTheme.success : AppTheme.textMuted,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final meetingProvider = Provider.of<MeetingProvider>(context);

    final activeHosted = meetingProvider.hostedMeetings.where((m) => !m.isMeetingExpired).toList();
    final activeInvited = meetingProvider.participatingMeetings.where((m) => !m.isMeetingExpired).toList();

    final Map<String, MeetingModel> historyMap = {};
    for (var m in meetingProvider.hostedMeetings) {
      if (m.isMeetingExpired) historyMap[m.uuid] = m;
    }
    for (var m in meetingProvider.participatingMeetings) {
      if (m.isMeetingExpired) historyMap[m.uuid] = m;
    }
    final historyMeetings = historyMap.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.record_voice_over, color: AppTheme.accentColor),
            SizedBox(width: 8),
            Text('MeetInt Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: 'Hosted (${activeHosted.length})'),
            Tab(text: 'Invited (${activeInvited.length})'),
            Tab(text: 'History (${historyMeetings.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Header welcome card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.cardDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.accentColor,
                      child: Text(
                        auth.user?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${auth.user?.name ?? 'User'}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            auth.user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Host Meeting',
                        icon: Icons.add_call,
                        height: 48,
                        backgroundColor: AppTheme.accentColor,
                        textColor: Colors.black,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Join with Code',
                        icon: Icons.meeting_room_outlined,
                        height: 48,
                        backgroundColor: AppTheme.surfaceDark,
                        onPressed: _onJoinByCodeDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Meetings Tab View
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => meetingProvider.fetchMeetings(),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMeetingList(activeHosted, isHosted: true, isHistory: false),
                  _buildMeetingList(activeInvited, isHosted: false, isHistory: false),
                  _buildMeetingList(historyMeetings, isHosted: false, isHistory: true),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildMeetingList(List<MeetingModel> meetings, {required bool isHosted, bool isHistory = false}) {
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history : (isHosted ? Icons.mic_none : Icons.event_busy),
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              isHistory ? 'No meeting history yet' : (isHosted ? 'No hosted meetings yet' : 'No invited meetings'),
              style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              isHistory ? 'Expired meetings & attendance reports appear here' : (isHosted ? 'Tap "Host Meeting" above to start an audio room' : 'Ask host for meeting code'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 40),
      itemCount: meetings.length,
      itemBuilder: (ctx, idx) {
        final m = meetings[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isHistory)
                      const StatusBadge(
                        text: 'EXPIRED',
                        color: AppTheme.error,
                        icon: Icons.timer_off,
                      )
                    else
                      StatusBadge(
                        text: m.visibility.toUpperCase(),
                        color: m.isPrivate ? AppTheme.warning : AppTheme.success,
                        icon: m.isPrivate ? Icons.lock : Icons.public,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.key, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'UUID: ${m.uuid}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (m.host != null && !isHosted) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: AppTheme.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        'Host: ${m.host!.name}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryLight),
                      ),
                    ],
                  ),
                ],
                if (m.approvalRequired && !isHistory) ...[
                  const SizedBox(height: 8),
                  const StatusBadge(
                    text: 'Approval Required',
                    color: AppTheme.info,
                    icon: Icons.verified_user,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: isHistory ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isHistory)
                      TextButton.icon(
                        onPressed: () {
                          final text = 'Join my Audio Meeting on MeetInt!\n\nTitle: ${m.title}\nMeeting Code: ${m.uuid}\n\nJoin link: https://vidbez.com/meeting/${m.uuid}';
                          Share.share(text, subject: 'Join Meeting: ${m.title}');
                        },
                        icon: const Icon(Icons.share, color: AppTheme.accentColor, size: 18),
                        label: const Text('Share Code', style: TextStyle(color: AppTheme.accentColor, fontSize: 13)),
                      ),
                    if (isHistory)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onPressed: () => _showMeetingReportDialog(context, m),
                          icon: const Icon(Icons.people_alt_outlined, size: 20, color: AppTheme.accentColor),
                          label: const Text(
                            'Participated Members',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _onJoinMeeting(m),
                        icon: const Icon(Icons.headset_mic, size: 18),
                        label: const Text('Join Room'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingApprovalDialog extends StatefulWidget {
  final String uuid;
  final Function(String, Map<String, dynamic>?) onApproved;
  final Function(String) onRejected;

  const _WaitingApprovalDialog({
    required this.uuid,
    required this.onApproved,
    required this.onRejected,
  });

  @override
  State<_WaitingApprovalDialog> createState() => _WaitingApprovalDialogState();
}

class _WaitingApprovalDialogState extends State<_WaitingApprovalDialog> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final meetingProvider = Provider.of<MeetingProvider>(context, listen: false);
      final res = await meetingProvider.joinMeeting(widget.uuid);

      if (!mounted) return;

      if (res['status'] == 'success' && res['data']?['access'] == 'granted') {
        _pollTimer?.cancel();
        Navigator.of(context).pop();
        widget.onApproved(widget.uuid, res['data'] is Map<String, dynamic> ? res['data'] : null);
      } else if (res['code'] == 'JOIN_REJECTED' || res['code'] == 'ACCESS_DENIED') {
        _pollTimer?.cancel();
        Navigator.of(context).pop();
        widget.onRejected(res['message'] ?? 'Host rejected your request to join this meeting.');
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.hourglass_top, color: AppTheme.warning),
          SizedBox(width: 10),
          Text('Asking to Join...', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          CircularProgressIndicator(color: AppTheme.warning),
          SizedBox(height: 20),
          Text(
            'Your join request has been sent to the Host.\nPlease wait while the host approves your request.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('Cancel Request'),
        ),
      ],
    );
  }
}
