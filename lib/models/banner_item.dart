class BannerItemModel {
  final String type; // 'news' or 'meeting'
  final String title;
  final String description;
  final String? imageUrl;
  final String? meetingUuid;
  final double price;
  final String? hostName;
  final int? hostId;
  final String? startsAt;

  BannerItemModel({
    required this.type,
    required this.title,
    required this.description,
    this.imageUrl,
    this.meetingUuid,
    this.price = 0.0,
    this.hostName,
    this.hostId,
    this.startsAt,
  });

  factory BannerItemModel.fromJson(Map<String, dynamic> json) {
    return BannerItemModel(
      type: json['type'] ?? 'news',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      meetingUuid: json['meeting_uuid'],
      price: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0,
      hostName: json['host_name'],
      hostId: json['host_id'] != null ? int.tryParse(json['host_id'].toString()) : null,
      startsAt: json['starts_at'],
    );
  }

  bool get isMeeting => type == 'meeting' && meetingUuid != null && meetingUuid!.isNotEmpty;
}
