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
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MeetingProvider>(context, listen: false).fetchMeetings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _onJoinMeeting(MeetingModel meeting) async {
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
            child: const Text('Join Now'),
          ),
        ],
      ),
    );
  }

  void _performJoin(String uuid) async {
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

    final res = await meetingProvider.joinMeeting(uuid);

    if (!mounted) return;
    Navigator.pop(context); // close loader

    if (res['status'] == 'success' && res['data']?['access'] == 'granted') {
      final data = res['data'];
      final token = data['token'];
      final livekitHost = data['livekit_host'] ?? 'http://127.0.0.1:7880';
      final role = data['role'] ?? 'participant';

      final meetingProvider = Provider.of<MeetingProvider>(context, listen: false);
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AudioRoomScreen()),
      );
    } else if (res['status'] == 'pending') {
      _showWaitingApprovalDialog(uuid);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Unable to join meeting'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showWaitingApprovalDialog(String uuid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: AppTheme.warning),
            SizedBox(width: 10),
            Text('Waiting for Host', style: TextStyle(color: Colors.white, fontSize: 18)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel Request'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _performJoin(uuid); // Check again
            },
            child: const Text('Check Approval Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final meetingProvider = Provider.of<MeetingProvider>(context);

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
            Tab(text: 'Hosted (${meetingProvider.hostedMeetings.length})'),
            Tab(text: 'Invited (${meetingProvider.participatingMeetings.length})'),
          ],
        ),
      ),
      body: Column(
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
                  _buildMeetingList(meetingProvider.hostedMeetings, isHosted: true),
                  _buildMeetingList(meetingProvider.participatingMeetings, isHosted: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingList(List<MeetingModel> meetings, {required bool isHosted}) {
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHosted ? Icons.mic_none : Icons.event_busy,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              isHosted ? 'No hosted meetings yet' : 'No invited meetings',
              style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              isHosted ? 'Tap "Host Meeting" above to start an audio room' : 'Ask host for meeting code',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (m.approvalRequired)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: StatusBadge(
                          text: 'Approval Required',
                          color: AppTheme.info,
                          icon: Icons.verified_user,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppTheme.accentColor, size: 20),
                      tooltip: 'Share Meeting Code',
                      onPressed: () {
                        final text = 'Join my Audio Meeting on MeetInt!\n\nTitle: ${m.title}\nMeeting Code: ${m.uuid}\n\nJoin link: https://vidbez.com/meeting/${m.uuid}';
                        Share.share(text, subject: 'Join Meeting: ${m.title}');
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _onJoinMeeting(m),
                      icon: const Icon(Icons.headset_mic, size: 18),
                      label: const Text('Join Audio Room'),
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
