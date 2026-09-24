class ChatMessage {
  final String senderName;
  final String senderEmail;
  final String message;
  final DateTime timestamp;
  final bool isHost;
  final bool isMe;

  ChatMessage({
    required this.senderName,
    required this.senderEmail,
    required this.message,
    required this.timestamp,
    this.isHost = false,
    this.isMe = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserEmail}) {
    final email = json['sender_email'] ?? json['email'] ?? '';
    return ChatMessage(
      senderName: json['sender_name'] ?? json['name'] ?? 'Guest',
      senderEmail: email,
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      isHost: json['is_host'] == true,
      isMe: currentUserEmail != null && email.toLowerCase() == currentUserEmail.toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_name': senderName,
      'sender_email': senderEmail,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_host': isHost,
    };
  }
}
