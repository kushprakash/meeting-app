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
      maxParticipants: json['max_participants'] != null
          ? (json['max_participants'] is int ? json['max_participants'] : int.tryParse(json['max_participants'].toString()))
          : null,
      host: json['host'] != null ? UserModel.fromJson(json['host']) : null,
      participants: list,
    );
  }

  bool get isPrivate => visibility == 'private';
  bool get isPublic => visibility == 'public';
}
