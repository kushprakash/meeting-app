import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/app_notification_item.dart';
import '../models/meeting.dart';
import '../providers/banner_notification_provider.dart';
import '../providers/meeting_provider.dart';

class NotificationsSheet extends StatelessWidget {
  final Function(String meetingUuid)? onJoinMeeting;

  const NotificationsSheet({super.key, this.onJoinMeeting});

  static void show(BuildContext context, {Function(String meetingUuid)? onJoinMeeting}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationsSheet(onJoinMeeting: onJoinMeeting),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BannerNotificationProvider, MeetingProvider>(
      builder: (context, notifProv, meetingProv, child) {
        final rawNotifications = notifProv.notifications;

        // Exclude notifications referencing expired/ended meetings
        final List<AppNotificationItem> notifications = [];
        for (var n in rawNotifications) {
          if (n.meetingUuid != null && n.meetingUuid!.isNotEmpty) {
            MeetingModel? meeting;
            for (var m in meetingProv.hostedMeetings) {
              if (m.uuid == n.meetingUuid) {
                meeting = m;
                break;
              }
            }
            if (meeting == null) {
              for (var m in meetingProv.participatingMeetings) {
                if (m.uuid == n.meetingUuid) {
                  meeting = m;
                  break;
                }
              }
            }

            if (meeting != null && meeting.isMeetingExpired) {
              continue;
            }
          }
          notifications.add(n);
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: AppTheme.accentColor, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (ctx, idx) {
                          final AppNotificationItem n = notifications[idx];
                          final isMeeting = n.meetingUuid != null && n.meetingUuid!.isNotEmpty;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                notifProv.markRead(n.id);
                                if (isMeeting && onJoinMeeting != null && n.meetingUuid != null) {
                                  Navigator.pop(context);
                                  onJoinMeeting!(n.meetingUuid!);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: n.isRead ? AppTheme.surfaceDark : AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: n.isRead ? Colors.white10 : AppTheme.accentColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isMeeting ? AppTheme.accentColor : AppTheme.info,
                                      child: Icon(
                                        isMeeting ? Icons.meeting_room : Icons.info_outline,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              if (!n.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppTheme.accentColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.message,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (isMeeting) ...[
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.accentColor,
                                                  foregroundColor: Colors.black,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  minimumSize: const Size(80, 30),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  notifProv.markRead(n.id);
                                                  Navigator.pop(context);
                                                  if (onJoinMeeting != null && n.meetingUuid != null) {
                                                    onJoinMeeting!(n.meetingUuid!);
                                                  }
                                                },
                                                icon: const Icon(Icons.headset, size: 14),
                                                label: const Text(
                                                  'Join Room',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
