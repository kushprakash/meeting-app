import 'user.dart';

class ParticipantModel {
  final int id;
  final int meetingId;
  final int? userId;
  final String email;
  final String role; // 'host' or 'participant'
  final String status; // 'invited', 'pending', 'approved', 'rejected', 'joined', 'left', 'removed', 'blocked'
  final UserModel? user;
  final String? approvedAt;
  final String? leftAt;

  ParticipantModel({
    required this.id,
    required this.meetingId,
    this.userId,
    required this.email,
    required this.role,
    required this.status,
    this.user,
    this.approvedAt,
    this.leftAt,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      meetingId: json['meeting_id'] is int ? json['meeting_id'] : int.parse(json['meeting_id'].toString()),
      userId: json['user_id'] != null ? (json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString())) : null,
      email: json['email'] ?? '',
      role: json['role'] ?? 'participant',
      status: json['status'] ?? 'pending',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      approvedAt: json['approved_at'],
      leftAt: json['left_at'],
    );
  }

  bool get isHost => role == 'host';
  bool get isApproved => status == 'approved' || status == 'joined';
  bool get isPending => status == 'pending';
}
