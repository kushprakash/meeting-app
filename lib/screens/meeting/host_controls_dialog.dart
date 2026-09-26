import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/participant.dart';
import '../../providers/livekit_room_provider.dart';

class HostControlsDialog extends StatefulWidget {
  final ParticipantModel participant;
  const HostControlsDialog({super.key, required this.participant});

  @override
  State<HostControlsDialog> createState() => _HostControlsDialogState();
}

class _HostControlsDialogState extends State<HostControlsDialog> {
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    final room = Provider.of<LiveKitRoomProvider>(context, listen: false);
    _isMuted = room.isParticipantMuted(widget.participant.email, userEmail: widget.participant.user?.email);
  }

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<LiveKitRoomProvider>(context);

    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              widget.participant.email.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.participant.user?.name ?? widget.participant.email,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.participant.email,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.red : AppTheme.success),
            title: Text(
              _isMuted ? 'Grant Speaking Permission (Unmute)' : 'Mute Microphone',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              setState(() {
                _isMuted = !_isMuted;
              });
              room.hostToggleParticipantMute(widget.participant, _isMuted);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isMuted ? 'Participant muted' : 'Participant unmuted'),
                  backgroundColor: AppTheme.info,
                ),
              );
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.person_remove, color: AppTheme.warning),
            title: const Text(
              'Remove from Meeting',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () async {
              Navigator.pop(context);
              final ok = await room.removeParticipant(widget.participant.id, widget.participant.email);
              if (ok) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Participant removed'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
