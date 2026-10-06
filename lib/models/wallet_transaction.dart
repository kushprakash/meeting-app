class WalletTransactionModel {
  final int id;
  final double amount;
  final String type; // 'credit' or 'debit'
  final String description;
  final String? referenceId;
  final String? createdAt;

  WalletTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.referenceId,
    this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      amount: json['amount'] != null ? double.parse(json['amount'].toString()) : 0.0,
      type: json['type'] ?? 'credit',
      description: json['description'] ?? '',
      referenceId: json['reference_id'],
      createdAt: json['created_at'],
    );
  }

  bool get isCredit => type.toLowerCase() == 'credit';
}
