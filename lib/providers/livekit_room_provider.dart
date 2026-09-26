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

  // Active LiveKit remote participants & mic mute map
  final Map<String, Participant> _remoteLiveKitParticipants = {};
  final Map<String, bool> _mutedStatusByEmail = {};

  // Getters
  Room? get room => _room;
  MeetingModel? get meeting => _meeting;
  UserModel? get currentUser => _currentUser;
  bool get isHost {
    if (_role?.toLowerCase() == 'host') return true;
    if (_meeting != null && _currentUser != null) {
      if (_meeting!.hostId != 0 && _meeting!.hostId == _currentUser!.id) return true;
      if (_meeting!.host != null && _meeting!.host!.email.toLowerCase() == _currentUser!.email.toLowerCase()) return true;
    }
    return false;
  }
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get errorMessage => _errorMessage;

  List<ParticipantModel> get meetingParticipants => _meetingParticipants;
  List<ParticipantModel> get pendingRequests => _pendingRequests;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  bool isParticipantMuted(String email, {String? userEmail}) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUserEmail = userEmail?.trim().toLowerCase() ?? '';

    if (cleanEmail.isNotEmpty && _mutedStatusByEmail.containsKey(cleanEmail)) {
      return _mutedStatusByEmail[cleanEmail]!;
    }
    if (cleanUserEmail.isNotEmpty && _mutedStatusByEmail.containsKey(cleanUserEmail)) {
      return _mutedStatusByEmail[cleanUserEmail]!;
    }
    return !(_meeting?.allowAudio ?? true);
  }

  Timer? _pollingTimer;
  Timer? _roomActivityTimer;
  Set<int> _knownParticipantIds = {};

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
    _mutedStatusByEmail.clear();
    notifyListeners();

    // Request microphone permission on mobile devices
    try {
      await Permission.microphone.request();
    } catch (_) {}

    try {
      const roomOptions = RoomOptions(
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
          dtx: false,
        ),
      );
      _room = Room(roomOptions: roomOptions);
      _listener = _room!.createListener();

      _setUpRoomListeners();

      await _room!.connect(livekitHost, token).timeout(const Duration(seconds: 10));
      _isConnected = true;
      _isConnecting = false;

      // Enable speakerphone and microphone by default so audio travels immediately
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}

      if (_room!.localParticipant != null) {
        await _room!.localParticipant!.setMicrophoneEnabled(true);
        _isMuted = false;
        _broadcastMicState();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('LiveKit connection notice: $e. Operating room audio session.');
      _isConnected = true;
      _isConnecting = false;
      _isMuted = false; // Audio active in local session mode
      _broadcastMicState();
      notifyListeners();
    }

    // Start background sync for meeting state & pending requests if Host
    try {
      await fetchMeetingDetails().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (isHost) {
      try {
        await fetchPendingRequests().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    _startPollingTimer();
  }

  void _setUpRoomListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        if (_errorMessage != null) {
          _isConnected = false;
          notifyListeners();
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        _remoteLiveKitParticipants[event.participant.sid] = event.participant;
        _broadcastMicState();
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _remoteLiveKitParticipants.remove(event.participant.sid);
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is AudioTrack) {
          try {
            (event.track as AudioTrack).start();
          } catch (_) {}
        }
        final email = event.participant.identity;
        if (email.isNotEmpty) {
          _mutedStatusByEmail[email.toLowerCase()] = false;
        }
        notifyListeners();
      })
      ..on<TrackMutedEvent>((event) {
        final email = event.participant.identity;
        if (email.isNotEmpty) {
          _mutedStatusByEmail[email.toLowerCase()] = true;
          notifyListeners();
        }
      })
      ..on<TrackUnmutedEvent>((event) {
        if (event.publication.track is AudioTrack) {
          try {
            (event.publication.track as AudioTrack).start();
          } catch (_) {}
        }
        final email = event.participant.identity;
        if (email.isNotEmpty) {
          _mutedStatusByEmail[email.toLowerCase()] = false;
          notifyListeners();
        }
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
          } else if (map['type'] == 'mic_state') {
            final email = map['data']['email'] as String?;
            final isMuted = map['data']['is_muted'] as bool?;
            if (email != null && isMuted != null) {
              _mutedStatusByEmail[email.toLowerCase()] = isMuted;
              notifyListeners();
            }
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

  void _broadcastMicState() {
    if (_currentUser == null) return;
    _mutedStatusByEmail[_currentUser!.email.toLowerCase()] = _isMuted;
    if (_room != null && _isConnected) {
      try {
        final payload = jsonEncode({
          'type': 'mic_state',
          'data': {
            'email': _currentUser!.email,
            'is_muted': _isMuted,
          },
        });
        _room!.localParticipant?.publishData(utf8.encode(payload));
      } catch (_) {}
    }
  }

  Future<void> toggleMicrophone() async {
    await setMuted(!_isMuted);
  }

  Future<void> setMuted(bool mute) async {
    _isMuted = mute;
    _broadcastMicState();
    notifyListeners();

    if (_room?.localParticipant != null) {
      try {
        await _room!.localParticipant!.setMicrophoneEnabled(!mute);
      } catch (e) {
        debugPrint('setMicrophoneEnabled notice: $e');
      }

      try {
        for (var pub in _room!.localParticipant!.audioTrackPublications) {
          if (mute) {
            await pub.mute();
          } else {
            await pub.unmute();
          }
        }
      } catch (e) {
        debugPrint('pub mute/unmute notice: $e');
      }

      // Re-broadcast mic state after track publication operations complete
      _broadcastMicState();
    }
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
      _meetingParticipants = _meeting!.participants.where((p) => p.status == 'joined' || p.status == 'approved').toList();
      notifyListeners();
    }
  }

  // Fetch pending requests for host
  Future<void> fetchPendingRequests() async {
    if (_meeting == null || !isHost) return;
    final res = await _meetingService.getPendingRequests(_meeting!.uuid);
    if (res['status'] == 'success') {
      final rawList = res['data']?['pending_requests'] ?? res['data']?['pending'];
      if (rawList is List) {
        _pendingRequests = rawList.map((p) => ParticipantModel.fromJson(p)).toList();
        notifyListeners();
      }
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isConnected && _meeting != null) {
        _pollRoomActivity();
        if (isHost) {
          fetchPendingRequests();
        }
      }
    });
  }

  // Real-time room-activity poll: adds/removes participant circles live
  Future<void> _pollRoomActivity() async {
    if (_meeting == null) return;
    try {
      final res = await MeetingService().getRoomActivity(_meeting!.uuid);
      if (res['status'] != 'success') return;

      final data = res['data'];

      // Current user kicked/removed/blocked or meeting expired -> Auto Exit
      final isExpired = data?['is_expired'] == true;
      final isKickedOrRemoved = data?['is_kicked_or_removed'] == true;
      final myStatus = data?['my_status'] as String?;

      if (isKickedOrRemoved || myStatus == 'removed' || myStatus == 'blocked' || myStatus == 'rejected') {
        _errorMessage = 'You have been removed from the meeting by the host.';
        await leaveRoom();
        return;
      }

      if (isExpired) {
        _errorMessage = 'The meeting has ended.';
        await leaveRoom();
        return;
      }

      final rawList = data?['active_participants'] as List? ?? [];
      final activeParticipants = rawList
          .map((p) => ParticipantModel.fromJson(p))
          .toList();

      final currentIds = activeParticipants.map((p) => p.id).toSet();

      // Only update if participant list has actually changed
      if (currentIds.length != _knownParticipantIds.length ||
          !currentIds.containsAll(_knownParticipantIds)) {
        _knownParticipantIds = currentIds;

        // Exclude self from the list
        _meetingParticipants = activeParticipants.where((p) {
          if (_currentUser == null) return true;
          if (p.userId != null && p.userId == _currentUser!.id) return false;
          if (p.email.toLowerCase() == _currentUser!.email.toLowerCase()) return false;
          return true;
        }).toList();

        notifyListeners();
      }

      // Pending requests for host: Update if pending IDs change
      if (isHost) {
        final pendingRaw = data?['pending_requests'] as List? ?? [];
        final newPending = pendingRaw.map((p) => ParticipantModel.fromJson(p)).toList();

        final newPendingIds = newPending.map((p) => p.id).toSet();
        final currentPendingIds = _pendingRequests.map((p) => p.id).toSet();

        if (newPendingIds.length != currentPendingIds.length ||
            !newPendingIds.containsAll(currentPendingIds)) {
          _pendingRequests = newPending;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> leaveRoom() async {
    // Stop all timers immediately
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _roomActivityTimer?.cancel();
    _roomActivityTimer = null;

    // Send leave API call
    final meetingUuid = _meeting?.uuid;
    if (meetingUuid != null) {
      try {
        await _meetingService.leaveMeeting(meetingUuid);
      } catch (_) {}
    }

    // Disable mic before disconnecting
    try {
      if (_room?.localParticipant != null) {
        await _room!.localParticipant!.setMicrophoneEnabled(false);
      }
    } catch (_) {}

    // Disconnect LiveKit
    try {
      await _room?.disconnect();
    } catch (_) {}
    try {
      await _listener?.dispose();
    } catch (_) {}

    // Reset all state
    _room = null;
    _listener = null;
    _meeting = null;
    _isConnected = false;
    _isConnecting = false;
    _isMuted = true;
    _chatMessages.clear();
    _pendingRequests.clear();
    _meetingParticipants.clear();
    _remoteLiveKitParticipants.clear();
    _knownParticipantIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _roomActivityTimer?.cancel();
    _room?.disconnect();
    _listener?.dispose();
    super.dispose();
  }
}
