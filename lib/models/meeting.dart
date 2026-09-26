import 'participant.dart';
import 'user.dart';

class MeetingModel {
  final int id;
  final String uuid;
  final String title;
  final int hostId;
  final String visibility; // 'private' or 'public'
  final bool approvalRequired;
  final String status; // 'active', 'ended'
  final bool allowAudio;
  final bool allowVideo;
  final bool allowScreenShare;
  final bool allowChat;
  final String? startsAt;
  final String? endsAt;
  final String? createdAt;
  final int? remainingSeconds;
  final bool isExpired;
  final int? maxParticipants;
  final UserModel? host;
  final List<ParticipantModel> participants;

  MeetingModel({
    required this.id,
    required this.uuid,
    required this.title,
    required this.hostId,
    required this.visibility,
    required this.approvalRequired,
    required this.status,
    required this.allowAudio,
    required this.allowVideo,
    required this.allowScreenShare,
    required this.allowChat,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.remainingSeconds,
    this.isExpired = false,
    this.maxParticipants,
    this.host,
    this.participants = const [],
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    var rawParticipants = json['participants'];
    List<ParticipantModel> list = [];
    if (rawParticipants is List) {
      list = rawParticipants.map((p) => ParticipantModel.fromJson(p)).toList();
    }

    return MeetingModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      uuid: json['uuid'] ?? '',
      title: json['title'] ?? 'Untitled Meeting',
      hostId: json['host_id'] is int ? json['host_id'] : int.parse(json['host_id'].toString()),
      visibility: json['visibility'] ?? 'public',
      approvalRequired: json['approval_required'] == true || json['approval_required'] == 1,
      status: json['status'] ?? 'active',
      allowAudio: json['allow_audio'] == true || json['allow_audio'] == 1 || json['allow_audio'] == null,
      allowVideo: json['allow_video'] == true || json['allow_video'] == 1,
      allowScreenShare: json['allow_screen_share'] == true || json['allow_screen_share'] == 1,
      allowChat: json['allow_chat'] == true || json['allow_chat'] == 1 || json['allow_chat'] == null,
      startsAt: json['starts_at'],
      endsAt: json['ends_at'],
      createdAt: json['created_at'],
      remainingSeconds: json['remaining_seconds'] != null
          ? (json['remaining_seconds'] is int ? json['remaining_seconds'] : int.tryParse(json['remaining_seconds'].toString()))
          : null,
      isExpired: json['is_expired'] == true || json['status'] == 'ended',
      maxParticipants: json['max_participants'] != null
          ? (json['max_participants'] is int ? json['max_participants'] : int.tryParse(json['max_participants'].toString()))
          : null,
      host: json['host'] != null ? UserModel.fromJson(json['host']) : null,
      participants: list,
    );
  }

  bool get isPrivate => visibility == 'private';
  bool get isPublic => visibility == 'public';

  bool get isMeetingExpired {
    if (isExpired || status == 'ended') return true;
    final now = DateTime.now();

    if (endsAt != null && endsAt!.isNotEmpty) {
      final dt = DateTime.tryParse(endsAt!);
      if (dt != null && now.isAfter(dt)) {
        return true;
      }
    }

    if (startsAt != null && startsAt!.isNotEmpty) {
      final st = DateTime.tryParse(startsAt!);
      if (st != null) {
        if (now.difference(st).inHours >= 12 || st.day != now.day || st.month != now.month || st.year != now.year) {
          return true;
        }
      }
    }

    if (createdAt != null && createdAt!.isNotEmpty) {
      final ct = DateTime.tryParse(createdAt!);
      if (ct != null) {
        if (now.difference(ct).inHours >= 12 || ct.day != now.day || ct.month != now.month || ct.year != now.year) {
          return true;
        }
      }
    }

    return false;
  }
}
