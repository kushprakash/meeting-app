import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/banner_item.dart';
import '../providers/auth_provider.dart';
import '../providers/banner_notification_provider.dart';
import '../providers/meeting_provider.dart';

class NewsBannerSliderWidget extends StatefulWidget {
  final Function(String meetingUuid) onJoinMeeting;

  const NewsBannerSliderWidget({super.key, required this.onJoinMeeting});

  @override
  State<NewsBannerSliderWidget> createState() => _NewsBannerSliderWidgetState();
}

class _NewsBannerSliderWidgetState extends State<NewsBannerSliderWidget> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 0.94);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final bannerProv = Provider.of<BannerNotificationProvider>(context, listen: false);
      if (bannerProv.banners.isNotEmpty) {
        _currentPage = (_currentPage + 1) % bannerProv.banners.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _confirmAndJoin(BuildContext context, BannerItemModel banner) {
    if (banner.meetingUuid == null) return;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final meetingProv = Provider.of<MeetingProvider>(context, listen: false);

    final currentUserId = authProv.user?.id;
    final isHost = (currentUserId != null && banner.hostId == currentUserId) ||
        meetingProv.hostedMeetings.any((m) => m.uuid == banner.meetingUuid);

    // Host user, free meetings, OR already paid meetings require NO payment! Direct join without payment dialog.
    if (isHost || banner.price <= 0 || banner.alreadyPaid) {
      widget.onJoinMeeting(banner.meetingUuid!);
      return;
    }

    final double fee = banner.price;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.accentColor, size: 28),
            SizedBox(width: 10),
            Text('Confirm Join Meeting', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to join this meeting?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              banner.title,
              style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Joining Amount Fee:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text(
                    fee > 0 ? '₹${fee.toStringAsFixed(2)}' : 'FREE',
                    style: TextStyle(
                      color: fee > 0 ? AppTheme.warning : AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (fee > 0)
              const Text(
                'This amount will be deducted directly from your wallet balance.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onJoinMeeting(banner.meetingUuid!);
            },
            child: Text(
              fee > 0 ? 'Confirm & Pay ₹${fee.toStringAsFixed(0)}' : 'Confirm & Join',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerNotificationProvider>(
      builder: (context, bannerProv, child) {
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        final meetingProv = Provider.of<MeetingProvider>(context, listen: false);

        final currentUserId = authProv.user?.id;
        final hostedUuids = meetingProv.hostedMeetings.map((m) => m.uuid).toSet();

        // Host ko slider me meeting show nahi hoga! Filter out hosted meeting banners for host user.
        final banners = bannerProv.banners.where((b) {
          if (b.isMeeting) {
            if (currentUserId != null && b.hostId == currentUserId) return false;
            if (b.meetingUuid != null && hostedUuids.contains(b.meetingUuid)) return false;
          }
          return true;
        }).toList();

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          height: 185, // Rich banner card carousel height for full width host and timer badge
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPage = idx;
                    });
                  },
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final BannerItemModel banner = banners[index];

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: banner.isMeeting
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [AppTheme.primaryColor, AppTheme.cardDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: banner.isMeeting ? AppTheme.accentColor.withValues(alpha: 0.4) : Colors.white10,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Top Row: Meeting Badge Tag & Joining Fee
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: banner.isMeeting ? AppTheme.accentColor : AppTheme.info,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          banner.isMeeting ? Icons.mic : Icons.campaign,
                                          size: 11,
                                          color: Colors.black,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          banner.isMeeting ? 'LIVE MEETING' : 'NEWS',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (banner.isMeeting) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: banner.alreadyPaid
                                            ? AppTheme.success.withValues(alpha: 0.2)
                                            : AppTheme.warning.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: banner.alreadyPaid ? AppTheme.success : AppTheme.warning,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        banner.alreadyPaid ? 'PAID ✓' : 'Fee: ₹${banner.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: banner.alreadyPaid ? AppTheme.success : AppTheme.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),

                          // 2. Middle Row: Title & Description
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                banner.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),

                          // 3. Full-width Host Row (Spans from Left to Right)
                          if (banner.hostName != null && banner.hostName!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.person_pin, size: 14, color: AppTheme.accentColor),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'By Host: ${banner.hostName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // 4. Bottom Row: Big Bold Time Counter + Join Room Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: MeetingCountdownBadge(banner: banner),
                              ),
                              const SizedBox(width: 8),
                              if (banner.isMeeting && banner.meetingUuid != null)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _confirmAndJoin(context, banner),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_fill, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        'Join Room',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (idx) {
                  final isSel = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSel ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSel ? AppTheme.accentColor : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MeetingCountdownBadge extends StatefulWidget {
  final BannerItemModel banner;

  const MeetingCountdownBadge({super.key, required this.banner});

  @override
  State<MeetingCountdownBadge> createState() => _MeetingCountdownBadgeState();
}

class _MeetingCountdownBadgeState extends State<MeetingCountdownBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    final startsAtStr = banner.startsAt;

    if (startsAtStr == null || startsAtStr.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: AppTheme.success),
            SizedBox(width: 4),
            Text('Meeting Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    try {
      // Clean timestamp string (e.g. "2026-10-06 20:30:00" or ISO format) to prevent double UTC offset conversion
      String cleanStr = startsAtStr.replaceAll('Z', '').replaceAll('T', ' ');
      final startDt = DateTime.parse(cleanStr);
      final now = DateTime.now();
      final diff = startDt.difference(now);
      final startTimeFormatted = DateFormat('hh:mm a').format(startDt);

      // Check if meeting is already live (host joined or status active/started or past startsAt time)
      final bool isRunning = banner.isLive || diff.isNegative;

      if (isRunning) {
        // Meeting is Running! Display "Meeting Started At:" and live duration
        final elapsed = diff.isNegative ? now.difference(startDt) : const Duration(minutes: 1);
        final hours = elapsed.inHours;
        final mins = elapsed.inMinutes % 60;
        final secs = elapsed.inSeconds % 60;

        String elapsedStr = hours > 0
            ? '${hours}h ${mins.toString().padLeft(2, '0')}m'
            : '${mins}m ${secs.toString().padLeft(2, '0')}s';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.success, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Meeting Started At $startTimeFormatted:',
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Text(
                    'Running ($elapsedStr)',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        // Meeting is Upcoming! Display "Meeting Starts In:"
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        final secs = diff.inSeconds % 60;

        String countdownStr = hours > 0
            ? '${hours}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s'
            : '${mins}m ${secs.toString().padLeft(2, '0')}s';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warning, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Meeting Starts In ($startTimeFormatted):',
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 12, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text(
                    countdownStr,
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } catch (_) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Live Session', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
  }
}
