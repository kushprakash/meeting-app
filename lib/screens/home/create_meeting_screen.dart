import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livekit_room_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../meeting/audio_room_screen.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _allowAudio = true;
  bool _allowChat = true;
  int _durationMinutes = 60;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentColor,
              onPrimary: Colors.black,
              surface: AppTheme.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentColor,
              onPrimary: Colors.black,
              surface: AppTheme.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final meetingProvider = Provider.of<MeetingProvider>(context, listen: false);

    final DateTime fullScheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final double price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    final meeting = await meetingProvider.createMeeting(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      visibility: 'public',
      approvalRequired: false,
      allowAudio: _allowAudio,
      allowChat: _allowChat,
      durationMinutes: _durationMinutes,
      startsAt: fullScheduledDateTime.toIso8601String(),
    );

    if (!mounted) return;

    if (meeting != null) {
      _showCreatedDialog(meeting.title, meeting.uuid);
    } else if (meetingProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(meetingProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _enterMeetingRoom(String uuid, BuildContext dialogContext) async {
    Navigator.pop(dialogContext); // Close dialog
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
      final res = await meetingProvider.joinMeeting(uuid);
      if (res['status'] == 'success' && res['data']?['access'] == 'granted') {
        final data = res['data'];
        final token = data['token'];
        final livekitHost = data['livekit_host'] ?? 'wss://bestrecharge.com/livekit/';
        final role = data['role'] ?? 'host';

        MeetingModel meeting = MeetingModel(
          id: 0,
          uuid: uuid,
          title: _titleController.text.trim().isEmpty ? 'Audio Room' : _titleController.text.trim(),
          hostId: authProvider.user?.id ?? 0,
          visibility: 'public',
          approvalRequired: false,
          status: 'active',
          allowAudio: _allowAudio,
          allowVideo: false,
          allowScreenShare: false,
          allowChat: _allowChat,
        );

        await livekitRoom.connectToRoom(
          meeting: meeting,
          currentUser: authProvider.user!,
          token: token,
          livekitHost: livekitHost,
          role: role,
        );

        if (!mounted) return;
        Navigator.pop(context); // Close loader
        Navigator.pop(context); // Exit create screen

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AudioRoomScreen()),
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to enter room'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining room: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showCreatedDialog(String title, String uuid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('Meeting Created!', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your meeting room has been successfully created.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Red Close button -> Returns to Dashboard Home page
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              // Right side: Info Join button -> Enters meeting room directly
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _enterMeetingRoom(uuid, ctx),
                icon: const Icon(Icons.meeting_room, size: 18),
                label: const Text(
                  'Join Room',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingProvider = Provider.of<MeetingProvider>(context);

    final String formattedDate = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    final String formattedTime = _selectedTime.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Audio Meeting'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Audio Room',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set schedule date & time and meeting join fee',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  controller: _titleController,
                  label: 'Meeting Title',
                  hint: 'e.g. Daily Tech Sync / Premium Masterclass',
                  prefixIcon: Icons.title_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Title is required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description / Topics',
                  hint: 'Brief summary of what this meeting is about...',
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 20),
                // Meeting Join Fee Field
                CustomTextField(
                  controller: _priceController,
                  label: 'Meeting Price / Join Fee (₹)',
                  hint: '0 for Free, or set amount e.g. 50',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please set meeting price (0 for Free)';
                    if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Schedule Date & Time Selectors
                const Text(
                  'Schedule Date & Time',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.accentColor, size: 18),
                              const SizedBox(width: 8),
                              Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppTheme.accentColor, size: 18),
                              const SizedBox(width: 8),
                              Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _durationMinutes,
                  dropdownColor: AppTheme.cardDark,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Duration (End Time)',
                    prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.accentColor),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                    DropdownMenuItem(value: 60, child: Text('60 Minutes (Standard Default)')),
                    DropdownMenuItem(value: 90, child: Text('90 Minutes')),
                    DropdownMenuItem(value: 120, child: Text('120 Minutes (2 Hours)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _durationMinutes = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                // Permissions switches
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppTheme.accentColor,
                  title: const Text(
                    'Allow Microphone Audio',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Participants can unmute & speak in the audio room',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  value: _allowAudio,
                  onChanged: (val) {
                    setState(() {
                      _allowAudio = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppTheme.accentColor,
                  title: const Text(
                    'Allow In-Meeting Chat',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Enable live text messaging room',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  value: _allowChat,
                  onChanged: (val) {
                    setState(() {
                      _allowChat = val;
                    });
                  },
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Create & Schedule Meeting',
                  icon: Icons.check_circle_outline,
                  isLoading: meetingProvider.isLoading,
                  onPressed: _handleCreate,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
