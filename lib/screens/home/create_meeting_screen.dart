import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/meeting_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _emailInputController = TextEditingController();

  String _visibility = 'public'; // 'public' or 'private'
  bool _approvalRequired = true;
  bool _allowAudio = true;
  bool _allowChat = true;

  final List<String> _invitedEmails = [];

  @override
  void dispose() {
    _titleController.dispose();
    _emailInputController.dispose();
    super.dispose();
  }

  void _addEmail() {
    final email = _emailInputController.text.trim().toLowerCase();
    if (email.isNotEmpty && email.contains('@')) {
      if (!_invitedEmails.contains(email)) {
        setState(() {
          _invitedEmails.add(email);
          _emailInputController.clear();
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _invitedEmails.remove(email);
    });
  }

  void _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final meetingProvider = Provider.of<MeetingProvider>(context, listen: false);
    final meeting = await meetingProvider.createMeeting(
      title: _titleController.text.trim(),
      visibility: _visibility,
      approvalRequired: _approvalRequired,
      allowAudio: _allowAudio,
      allowChat: _allowChat,
      invitedEmails: _invitedEmails,
    );

    if (!mounted) return;

    if (meeting != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting created successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } else if (meetingProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(meetingProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingProvider = Provider.of<MeetingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Audio Meeting'),
      ),
      body: SingleChildScrollView(
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
                'Configure meeting settings and privacy permissions',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              CustomTextField(
                controller: _titleController,
                label: 'Meeting Title',
                hint: 'e.g. Technical Discussion / Public Webinar',
                prefixIcon: Icons.title_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'Public Meeting',
                      subtitle: 'Anyone with code can request',
                      icon: Icons.public,
                      isSelected: _visibility == 'public',
                      onTap: () {
                        setState(() {
                          _visibility = 'public';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'Private Meeting',
                      subtitle: 'Only invited emails can join',
                      icon: Icons.lock_outline,
                      isSelected: _visibility == 'private',
                      onTap: () {
                        setState(() {
                          _visibility = 'private';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Approval toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppTheme.accentColor,
                title: const Text(
                  'Require Host Approval',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Host receives join request before letting users enter',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                value: _approvalRequired,
                onChanged: (val) {
                  setState(() {
                    _approvalRequired = val;
                  });
                },
              ),
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
                  'Participants can unmute & speak (Host controls permissions)',
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
              const SizedBox(height: 20),
              // Email invitation section
              const Text(
                'Invite Participants (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailInputController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'participant@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      backgroundColor: AppTheme.surfaceDark,
                    ),
                    onPressed: _addEmail,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              if (_invitedEmails.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _invitedEmails.map((email) {
                    return Chip(
                      backgroundColor: AppTheme.surfaceDark,
                      label: Text(email, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () => _removeEmail(email),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 36),
              CustomButton(
                text: 'Create & Launch Room',
                icon: Icons.check_circle_outline,
                isLoading: meetingProvider.isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.25) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.accentColor : AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
