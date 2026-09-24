import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/livekit_room_provider.dart';

class ParticipantRequestsDialog extends StatelessWidget {
  const ParticipantRequestsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<LiveKitRoomProvider>(context);
    final requests = room.pendingRequests;

    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.person_add, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Text(
            'Pending Requests (${requests.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: requests.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No pending join requests',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: requests.length,
                itemBuilder: (ctx, idx) {
                  final p = requests[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            (p.user?.name ?? p.email).substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.user?.name ?? 'Guest User',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                p.email,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.error),
                          onPressed: () async {
                            await room.rejectPendingUser(p.id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: AppTheme.success),
                          onPressed: () async {
                            await room.approvePendingUser(p.id);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
