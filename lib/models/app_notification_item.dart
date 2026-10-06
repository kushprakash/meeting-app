class AppNotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? meetingUuid;
  final bool isRead;
  final String? createdAt;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.meetingUuid,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      meetingUuid: json['meeting_uuid'],
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'],
    );
  }
}
