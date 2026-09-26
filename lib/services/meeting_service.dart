import 'api_service.dart';

class MeetingService {
  Future<Map<String, dynamic>> createMeeting({
    required String title,
    required String visibility, // 'public' or 'private'
    required bool approvalRequired,
    required bool allowAudio,
    required bool allowChat,
    int durationMinutes = 60,
    List<String>? invitedEmails,
  }) async {
    return await ApiService.post('/meetings', {
      'title': title,
      'visibility': visibility,
      'approval_required': approvalRequired,
      'allow_audio': allowAudio,
      'allow_video': false,
      'allow_screen_share': false,
      'allow_chat': allowChat,
      'duration_minutes': durationMinutes,
      'invited_emails': invitedEmails ?? [],
    });
  }

  Future<Map<String, dynamic>> getMeetings() async {
    return await ApiService.get('/meetings');
  }

  Future<Map<String, dynamic>> getMeetingDetails(String uuid) async {
    return await ApiService.get('/meetings/$uuid');
  }

  Future<Map<String, dynamic>> joinMeeting(String uuid) async {
    return await ApiService.post('/meetings/$uuid/join', {});
  }

  Future<Map<String, dynamic>> getPendingRequests(String uuid) async {
    return await ApiService.get('/meetings/$uuid/pending');
  }

  Future<Map<String, dynamic>> approveParticipant(String uuid, int participantId) async {
    return await ApiService.post('/meetings/$uuid/approve/$participantId', {});
  }

  Future<Map<String, dynamic>> rejectParticipant(String uuid, int participantId) async {
    return await ApiService.post('/meetings/$uuid/reject/$participantId', {});
  }

  Future<Map<String, dynamic>> removeParticipant(String uuid, int participantId) async {
    return await ApiService.post('/meetings/$uuid/remove/$participantId', {});
  }

  Future<Map<String, dynamic>> blockParticipant(String uuid, int participantId) async {
    return await ApiService.post('/meetings/$uuid/block/$participantId', {});
  }

  Future<Map<String, dynamic>> inviteParticipants(String uuid, List<String> emails) async {
    return await ApiService.post('/meetings/$uuid/invite', {
      'emails': emails,
    });
  }

  Future<Map<String, dynamic>> getRoomActivity(String uuid) async {
    return await ApiService.get('/meetings/$uuid/room-activity');
  }

  Future<Map<String, dynamic>> leaveMeeting(String uuid) async {
    return await ApiService.post('/meetings/$uuid/leave', {});
  }
}
