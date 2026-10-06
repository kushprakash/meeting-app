import 'package:flutter/material.dart';
import '../models/passbook_item.dart';
import '../services/api_service.dart';

class WalletProvider extends ChangeNotifier {
  double _walletBalance = 0.0;
  List<PassbookItemModel> _passbooks = [];
  bool _isLoading = false;
  String? _errorMessage;

  double get walletBalance => _walletBalance;
  List<PassbookItemModel> get passbooks => _passbooks;
  List<PassbookItemModel> get transactions => _passbooks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchWallet() async {
    _isLoading = true;
    notifyListeners();

    final res = await ApiService.get('/wallet');
    _isLoading = false;

    if (res['status'] == 'success' && res['data'] != null) {
      final data = res['data'];
      if (data['wallet_balance'] != null) {
        _walletBalance = double.tryParse(data['wallet_balance'].toString()) ?? 0.0;
      } else if (data['balance'] != null) {
        _walletBalance = double.tryParse(data['balance'].toString()) ?? 0.0;
      }

      final rawPassbooks = data['passbook'] ?? data['transactions'];
      if (rawPassbooks is List) {
        _passbooks = rawPassbooks
            .map((t) => PassbookItemModel.fromJson(t))
            .toList();
      }
      _errorMessage = null;
    } else {
      _errorMessage = res['message'] ?? 'Failed to load wallet passbook';
    }
    notifyListeners();
  }

  Future<bool> addMoney(double amount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await ApiService.post('/wallet/add-money', {
      'amount': amount,
      'details': 'Added Money to Wallet',
    });
    _isLoading = false;

    if (res['status'] == 'success' && res['data'] != null) {
      final data = res['data'];
      if (data['wallet_balance'] != null) {
        _walletBalance = double.tryParse(data['wallet_balance'].toString()) ?? _walletBalance;
      } else if (data['balance'] != null) {
        _walletBalance = double.tryParse(data['balance'].toString()) ?? _walletBalance;
      }
      await fetchWallet();
      return true;
    } else {
      _errorMessage = res['message'] ?? 'Failed to add money';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> initiatePayment(double amount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await ApiService.post('/wallet/initiate-payment', {
      'amount': amount,
    });
    _isLoading = false;
    notifyListeners();
    return res;
  }

  Future<bool> verifyPayment(String txnid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await ApiService.post('/wallet/verify-payment', {
      'txnid': txnid,
    });
    _isLoading = false;

    if (res['status'] == 'success' && res['data'] != null) {
      await fetchWallet();
      return true;
    } else {
      _errorMessage = res['message'] ?? 'Payment verification failed';
      notifyListeners();
      return false;
    }
  }

  void updateBalanceLocally(double newBalance) {
    _walletBalance = newBalance;
    notifyListeners();
  }
}
