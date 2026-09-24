class UserModel {
  final int id;
  final String name;
  final String email;
  final String? accountType;
  final bool emailVerified;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.accountType,
    this.emailVerified = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      accountType: json['account_type'],
      emailVerified: json['email_verified_at'] != null,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'account_type': accountType,
      'email_verified_at': emailVerified ? DateTime.now().toIso8601String() : null,
      'created_at': createdAt,
    };
  }
}
