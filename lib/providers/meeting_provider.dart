import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../services/meeting_service.dart';

class MeetingProvider extends ChangeNotifier {
  final MeetingService _meetingService = MeetingService();

  List<MeetingModel> _hostedMeetings = [];
  List<MeetingModel> _participatingMeetings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<MeetingModel> get hostedMeetings => _hostedMeetings;
  List<MeetingModel> get participatingMeetings => _participatingMeetings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMeetings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _meetingService.getMeetings();
    _isLoading = false;

    if (res['status'] == 'success' && res['data'] != null) {
      final hostedList = res['data']['hosted'] as List? ?? [];
      final partList = res['data']['participating'] as List? ?? [];

      _hostedMeetings = hostedList.map((m) => MeetingModel.fromJson(m)).toList();
      _participatingMeetings = partList.map((m) => MeetingModel.fromJson(m)).toList();
    } else {
      _errorMessage = res['message'] ?? 'Failed to load meetings';
    }
    notifyListeners();
  }

  Future<MeetingModel?> createMeeting({
    required String title,
    required String visibility,
    required bool approvalRequired,
    required bool allowAudio,
    required bool allowChat,
    int durationMinutes = 60,
    List<String>? invitedEmails,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _meetingService.createMeeting(
      title: title,
      visibility: visibility,
      approvalRequired: approvalRequired,
      allowAudio: allowAudio,
      allowChat: allowChat,
      durationMinutes: durationMinutes,
      invitedEmails: invitedEmails,
    );

    _isLoading = false;

    if (res['status'] == 'success' && res['data']?['meeting'] != null) {
      final meeting = MeetingModel.fromJson(res['data']['meeting']);
      _hostedMeetings.insert(0, meeting);
      notifyListeners();
      return meeting;
    } else {
      _errorMessage = res['message'] ?? 'Failed to create meeting';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>> joinMeeting(String uuid) async {
    return await _meetingService.joinMeeting(uuid);
  }
}
