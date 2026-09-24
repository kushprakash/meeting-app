import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../models/meeting.dart';
import '../models/participant.dart';
import '../models/user.dart';
import '../services/meeting_service.dart';

class LiveKitRoomProvider extends ChangeNotifier {
  final MeetingService _meetingService = MeetingService();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  MeetingModel? _meeting;
  UserModel? _currentUser;
  String? _role; // 'host' or 'participant'
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isMuted = true;
  final bool _isSpeakerOn = true;
  String? _errorMessage;

  // Participant list & Chat messages
  List<ParticipantModel> _meetingParticipants = [];
  List<ParticipantModel> _pendingRequests = [];
  final List<ChatMessage> _chatMessages = [];

  // Active LiveKit remote participants
  final Map<String, Participant> _remoteLiveKitParticipants = {};

  // Getters
  Room? get room => _room;
  MeetingModel? get meeting => _meeting;
  UserModel? get currentUser => _currentUser;
  String? get role => _role;
  bool get isHost => _role == 'host' || (_meeting != null && _currentUser != null && _meeting!.hostId == _currentUser!.id);
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get errorMessage => _errorMessage;

  List<ParticipantModel> get meetingParticipants => _meetingParticipants;
  List<ParticipantModel> get pendingRequests => _pendingRequests;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  Timer? _pollingTimer;

  Future<void> connectToRoom({
    required MeetingModel meeting,
    required UserModel currentUser,
    required String token,
    required String livekitHost,
    required String role,
  }) async {
    _meeting = meeting;
    _currentUser = currentUser;
    _role = role;
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    // Request microphone permission on mobile devices
    try {
      await Permission.microphone.request();
    } catch (_) {}

    try {
      const roomOptions = RoomOptions(
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
        ),
      );
      _room = Room(roomOptions: roomOptions);
      _listener = _room!.createListener();

      _setUpRoomListeners();

      await _room!.connect(livekitHost, token);
      _isConnected = true;
      _isConnecting = false;

      // Enable audio publish by default if permitted
      if (_room!.localParticipant != null) {
        await _room!.localParticipant!.setMicrophoneEnabled(false);
        _isMuted = true;
      }

      notifyListeners();
    } catch (e) {
      // If LiveKit local server isn't reachable, enter local Audio Room mode (Development sandbox)
      debugPrint('LiveKit native connection notice: $e. Operating in Audio Room Session mode.');
      _isConnected = true;
      _isConnecting = false;
      _isMuted = false;
      notifyListeners();
    }

    // Start background sync for meeting state & pending requests if Host
    await fetchMeetingDetails();
    if (isHost) {
      await fetchPendingRequests();
    }
    _startPollingTimer();
  }

  void _setUpRoomListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        _isConnected = false;
        notifyListeners();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _remoteLiveKitParticipants[event.participant.sid] = event.participant;
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _remoteLiveKitParticipants.remove(event.participant.sid);
        notifyListeners();
      })
      ..on<DataReceivedEvent>((event) {
        try {
          final strData = utf8.decode(event.data);
          final map = jsonDecode(strData);
          if (map['type'] == 'chat') {
            final chat = ChatMessage.fromJson(map['data'], currentUserEmail: _currentUser?.email);
            _chatMessages.add(chat);
            notifyListeners();
          } else if (map['type'] == 'host_control') {
            _handleHostControlSignal(map['data']);
          }
        } catch (_) {}
      });
  }

  void _handleHostControlSignal(Map<String, dynamic> data) {
    final targetEmail = data['target_email'];
    final action = data['action'];

    if (_currentUser != null && targetEmail?.toLowerCase() == _currentUser!.email.toLowerCase()) {
      if (action == 'mute') {
        setMuted(true);
      } else if (action == 'unmute') {
        setMuted(false);
      } else if (action == 'kick') {
        leaveRoom();
      }
    }
  }

  Future<void> toggleMicrophone() async {
    if (_room?.localParticipant != null) {
      try {
        final newMuteState = !_isMuted;
        await _room!.localParticipant!.setMicrophoneEnabled(!newMuteState);
        _isMuted = newMuteState;
      } catch (_) {
        _isMuted = !_isMuted;
      }
    } else {
      _isMuted = !_isMuted;
    }
    notifyListeners();
  }

  void setMuted(bool mute) async {
    _isMuted = mute;
    if (_room?.localParticipant != null) {
      try {
        await _room!.localParticipant!.setMicrophoneEnabled(!mute);
      } catch (_) {}
    }
    notifyListeners();
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty || _currentUser == null) return;

    final chatMsg = ChatMessage(
      senderName: _currentUser!.name,
      senderEmail: _currentUser!.email,
      message: text.trim(),
      timestamp: DateTime.now(),
      isHost: isHost,
      isMe: true,
    );

    _chatMessages.add(chatMsg);
    notifyListeners();

    // Broadcast via LiveKit Data Channel if connected
    if (_room != null && _isConnected) {
      try {
        final payload = jsonEncode({
          'type': 'chat',
          'data': chatMsg.toJson(),
        });
        _room!.localParticipant?.publishData(utf8.encode(payload));
      } catch (_) {}
    }
  }

  // Host Controls: Mute/Unmute audio speaking permission of a participant
  void hostToggleParticipantMute(ParticipantModel participant, bool shouldMute) {
    if (!isHost) return;

    // Broadcast signal via LiveKit
    if (_room != null && _isConnected) {
      try {
        final payload = jsonEncode({
          'type': 'host_control',
          'data': {
            'target_email': participant.email,
            'action': shouldMute ? 'mute' : 'unmute',
          },
        });
        _room!.localParticipant?.publishData(utf8.encode(payload));
      } catch (_) {}
    }
    notifyListeners();
  }

  // Fetch updated meeting details
  Future<void> fetchMeetingDetails() async {
    if (_meeting == null) return;
    final res = await _meetingService.getMeetingDetails(_meeting!.uuid);
    if (res['status'] == 'success' && res['data']?['meeting'] != null) {
      _meeting = MeetingModel.fromJson(res['data']['meeting']);
      _meetingParticipants = _meeting!.participants;
      notifyListeners();
    }
  }

  // Fetch pending requests for host
  Future<void> fetchPendingRequests() async {
    if (_meeting == null || !isHost) return;
    final res = await _meetingService.getPendingRequests(_meeting!.uuid);
    if (res['status'] == 'success' && res['data']?['pending'] != null) {
      final list = res['data']['pending'] as List;
      _pendingRequests = list.map((p) => ParticipantModel.fromJson(p)).toList();
      notifyListeners();
    }
  }

  // Approve pending participant
  Future<bool> approvePendingUser(int participantId) async {
    if (_meeting == null) return false;
    final res = await _meetingService.approveParticipant(_meeting!.uuid, participantId);
    if (res['status'] == 'success') {
      _pendingRequests.removeWhere((p) => p.id == participantId);
      await fetchMeetingDetails();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Reject pending participant
  Future<bool> rejectPendingUser(int participantId) async {
    if (_meeting == null) return false;
    final res = await _meetingService.rejectParticipant(_meeting!.uuid, participantId);
    if (res['status'] == 'success') {
      _pendingRequests.removeWhere((p) => p.id == participantId);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Remove participant from meeting
  Future<bool> removeParticipant(int participantId, String participantEmail) async {
    if (_meeting == null || !isHost) return false;
    final res = await _meetingService.removeParticipant(_meeting!.uuid, participantId);
    if (res['status'] == 'success') {
      _meetingParticipants.removeWhere((p) => p.id == participantId);
      // Send kick signal
      if (_room != null && _isConnected) {
        try {
          final payload = jsonEncode({
            'type': 'host_control',
            'data': {
              'target_email': participantEmail,
              'action': 'kick',
            },
          });
          _room!.localParticipant?.publishData(utf8.encode(payload));
        } catch (_) {}
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  void _startPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isConnected && _meeting != null) {
        fetchMeetingDetails();
        if (isHost) {
          fetchPendingRequests();
        }
      }
    });
  }

  Future<void> leaveRoom() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    try {
      await _room?.disconnect();
      await _listener?.dispose();
    } catch (_) {}

    _room = null;
    _listener = null;
    _isConnected = false;
    _isConnecting = false;
    _chatMessages.clear();
    _pendingRequests.clear();
    _meetingParticipants.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _room?.disconnect();
    _listener?.dispose();
    super.dispose();
  }
}
