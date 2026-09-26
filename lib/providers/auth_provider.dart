import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;
  String? _pendingEmail;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  String? get pendingEmail => _pendingEmail;

  AuthProvider() {
    initAuth();
  }

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await ApiService.getToken();
      if (token != null && token.isNotEmpty) {
        _user = await _authService.getProfile();
      }
    } catch (_) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    String? phone,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _authService.register(name: name, phone: phone, email: email, password: password);
    _isLoading = false;

    if (res['status'] == 'pending_otp') {
      _pendingEmail = email;
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _authService.verifyOtp(email: email, otpCode: otpCode);
    _isLoading = false;

    if (res['status'] == 'success' && res['data']?['user'] != null) {
      _user = UserModel.fromJson(res['data']['user']);
      _pendingEmail = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = res['message'] ?? 'Verification failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _authService.login(email: email, password: password);
    _isLoading = false;

    if (res['status'] == 'success' && res['data']?['user'] != null) {
      _user = UserModel.fromJson(res['data']['user']);
      notifyListeners();
      return true;
    } else if (res['status'] == 'pending_otp') {
      _pendingEmail = email;
      notifyListeners();
      return false; // Redirect to OTP screen
    } else {
      _errorMessage = res['message'] ?? 'Invalid credentials';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
