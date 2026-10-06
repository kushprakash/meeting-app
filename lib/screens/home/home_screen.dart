import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banner_notification_provider.dart';
import '../../providers/livekit_room_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/news_banner_slider_widget.dart';
import '../../widgets/notifications_sheet.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/utility_services_grid_widget.dart';
import '../../widgets/wallet_card_widget.dart';
import '../auth/login_screen.dart';
import '../meeting/audio_room_screen.dart';
import 'create_meeting_screen.dart';

import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _formatDisplayDateTime(String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return 'Now Active';
    try {
      final dt = DateTime.parse(rawStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return rawStr;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _refreshAllData();
      _checkPendingMeeting();
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      Provider.of<MeetingProvider>(context, listen: false).fetchMeetings(),
      Provider.of<WalletProvider>(context, listen: false).fetchWallet(),
      Provider.of<BannerNotificationProvider>(
        context,
        listen: false,
      ).fetchAllData(),
    ]);
  }

  void _checkPendingMeeting() async {
    final pendingUuid = await ApiService.getPendingMeetingUuid();
    if (pendingUuid != null && pendingUuid.isNotEmpty) {
      await ApiService.removePendingMeetingUuid();
      _performJoin(pendingUuid);
    }
  }

  void _performJoin(String uuid, [Map<String, dynamic>? preFetchedData]) async {
    final meetingProvider = Provider.of<MeetingProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final livekitRoom = Provider.of<LiveKitRoomProvider>(
      context,
      listen: false,
    );
    final walletProv = Provider.of<WalletProvider>(context, listen: false);

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
        final livekitHost =
            data['livekit_host'] ?? 'wss://bestrecharge.com/livekit/';
        final role = data['role'] ?? 'participant';

        // Refresh wallet balance after potential fee deduction
        walletProv.fetchWallet();

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
          meeting = meetingProvider.hostedMeetings.firstWhere(
            (m) => m.uuid == uuid,
          );
        } else if (meetingProvider.participatingMeetings.any(
          (m) => m.uuid == uuid,
        )) {
          meeting = meetingProvider.participatingMeetings.firstWhere(
            (m) => m.uuid == uuid,
          );
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

        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AudioRoomScreen()));
      } else if (res['code'] == 'INSUFFICIENT_FUNDS') {
        Navigator.pop(context); // Close loader
        final double reqAmt = (res['data']?['required_amount'] != null)
            ? double.tryParse(res['data']['required_amount'].toString()) ?? 0.0
            : 0.0;
        WalletCardWidget.showAddMoneyDialog(context, reqAmt);
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
                const Icon(
                  Icons.assessment_outlined,
                  color: AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Attendance & Meeting Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Code (UUID): ${m.uuid}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
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
                        const Text(
                          'Host:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          m.host?.name ?? 'Host User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          m.host?.email ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                                backgroundColor: p.isHost
                                    ? AppTheme.warning
                                    : AppTheme.primaryColor,
                                child: Text(
                                  (p.user?.name ?? p.email)
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.user?.name ?? 'Guest User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      p.email,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                text: p.role.toUpperCase(),
                                color: p.isHost
                                    ? AppTheme.warning
                                    : AppTheme.info,
                              ),
                              const SizedBox(width: 6),
                              StatusBadge(
                                text: p.status.toUpperCase(),
                                color: p.isApproved
                                    ? AppTheme.success
                                    : AppTheme.textMuted,
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
    final notifProv = Provider.of<BannerNotificationProvider>(context);

    final isCorporate = auth.user?.isCorporate ?? false;

    // Filter meeting history ONLY (Last 5 meetings max)
    final Map<String, MeetingModel> historyMap = {};
    for (var m in meetingProvider.hostedMeetings) {
      if (m.isMeetingExpired) historyMap[m.uuid] = m;
    }
    for (var m in meetingProvider.participatingMeetings) {
      if (m.isMeetingExpired) historyMap[m.uuid] = m;
    }
    final historyMeetings = historyMap.values.toList().take(5).toList();

    // Filter upcoming/active meetings for Corporate users
    final Map<String, MeetingModel> upcomingMap = {};
    for (var m in meetingProvider.hostedMeetings) {
      if (!m.isMeetingExpired) upcomingMap[m.uuid] = m;
    }
    for (var m in meetingProvider.participatingMeetings) {
      if (!m.isMeetingExpired) upcomingMap[m.uuid] = m;
    }
    final upcomingMeetings = upcomingMap.values.toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          child: CustomScrollView(
            slivers: [
              // Custom Top Header App Bar (Profile Icon & Name + Notification Bell)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Left: Profile avatar icon & name
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.accentColor,
                            child: Text(
                              auth.user?.name.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.user?.name ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                isCorporate
                                    ? 'Corporate Account (${auth.user?.accountType})'
                                    : 'Best Recharge Member',
                                style: TextStyle(
                                  color: isCorporate
                                      ? AppTheme.accentColor
                                      : AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: isCorporate
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Top Right: Notification Bell Icon with Badge Count & Logout
                      Row(
                        children: [
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  NotificationsSheet.show(
                                    context,
                                    onJoinMeeting: _performJoin,
                                  );
                                },
                              ),
                              if (notifProv.unreadCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${notifProv.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white70,
                            ),
                            tooltip: 'Logout',
                            onPressed: () async {
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Wallet Card Widget
              const SliverToBoxAdapter(child: WalletCardWidget()),

              // Corporate Host Feature: Create Meeting Action Card
              if (isCorporate)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.3),
                          AppTheme.cardDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.business_center,
                                    color: AppTheme.accentColor,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Corporate Host Suite',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create & Host Audio Rooms',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateMeetingScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text(
                            'Create Meeting',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Banner Slider Carousel (Positioned Directly ABOVE Utility Services)
              SliverToBoxAdapter(
                child: NewsBannerSliderWidget(
                  onJoinMeeting: (uuid) => _performJoin(uuid),
                ),
              ),

              // 3. Utility Services Section Grid
              SliverToBoxAdapter(child: UtilityServicesGridWidget()),

              // Corporate Host Feature: Upcoming Meetings Section
              if (isCorporate) ...[
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_available,
                              color: AppTheme.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Upcoming Meetings (${upcomingMeetings.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceDark,
                            foregroundColor: AppTheme.accentColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateMeetingScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text(
                            'Create',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  sliver: upcomingMeetings.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.event_note,
                                  color: AppTheme.textMuted,
                                  size: 32,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No upcoming meetings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Tap "Create Meeting" to schedule an audio room',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, idx) {
                            final m = upcomingMeetings[idx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppTheme.success.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1,
                                ),
                              ),
                              color: AppTheme.cardDark,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  m.title,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const StatusBadge(
                                                text: 'ACTIVE',
                                                color: AppTheme.success,
                                                icon: Icons.graphic_eq,
                                              ),
                                            ],
                                          ),
                                          if (m.description != null &&
                                              m.description!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              m.description!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.schedule,
                                                size: 12,
                                                color: AppTheme.accentColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _formatDisplayDateTime(
                                                    m.startsAt ?? m.createdAt,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.accentColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (m.price > 0) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '• Fee: ₹${m.price.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.warning,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Direct Connect / Join Button
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _performJoin(m.uuid),
                                      icon: const Icon(
                                        Icons.meeting_room,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Enter Room',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: upcomingMeetings.length),
                        ),
                ),
              ],

              // 4. Meeting History Section Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Meeting History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Meeting History List
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                sliver: historyMeetings.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 48,
                                  color: AppTheme.textMuted,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No meeting history yet',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Completed sessions & reports appear here',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, idx) {
                          final m = historyMeetings[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppTheme.surfaceDark,
                                width: 1,
                              ),
                            ),
                            color: AppTheme.cardDark,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left side: Title, Description, Date & Time
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (m.description != null &&
                                            m.description!
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            m.description!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12,
                                              color: AppTheme.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _formatDisplayDateTime(
                                                  m.startsAt ?? m.createdAt,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Right side: Small Details Button
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accentColor,
                                      side: const BorderSide(
                                        color: AppTheme.accentColor,
                                        width: 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showMeetingReportDialog(context, m),
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: historyMeetings.length),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
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
      final meetingProvider = Provider.of<MeetingProvider>(
        context,
        listen: false,
      );
      final res = await meetingProvider.joinMeeting(widget.uuid);

      if (!mounted) return;

      if (res['status'] == 'success' && res['data']?['access'] == 'granted') {
        _pollTimer?.cancel();
        Navigator.of(context).pop();
        widget.onApproved(
          widget.uuid,
          res['data'] is Map<String, dynamic> ? res['data'] : null,
        );
      } else if (res['code'] == 'JOIN_REJECTED' ||
          res['code'] == 'ACCESS_DENIED') {
        _pollTimer?.cancel();
        Navigator.of(context).pop();
        widget.onRejected(
          res['message'] ?? 'Host rejected your request to join this meeting.',
        );
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
          Text(
            'Asking to Join...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
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
