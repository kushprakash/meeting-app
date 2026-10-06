class PassbookItemModel {
  final int id;
  final int userId;
  final String details;
  final String type; // 'CR' or 'DR'
  final double preBalance;
  final double amount;
  final double balance;
  final String? createdAt;

  PassbookItemModel({
    required this.id,
    required this.userId,
    required this.details,
    required this.type,
    required this.preBalance,
    required this.amount,
    required this.balance,
    this.createdAt,
  });

  factory PassbookItemModel.fromJson(Map<String, dynamic> json) {
    return PassbookItemModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse((json['user_id'] ?? 0).toString()),
      details: json['details'] ?? '',
      type: json['type'] ?? 'CR',
      preBalance: json['pre_balance'] != null ? double.parse(json['pre_balance'].toString()) : 0.0,
      amount: json['amount'] != null ? double.parse(json['amount'].toString()) : 0.0,
      balance: json['balance'] != null ? double.parse(json['balance'].toString()) : 0.0,
      createdAt: json['created_at'],
    );
  }

  bool get isCredit => type.toUpperCase() == 'CR';
}
