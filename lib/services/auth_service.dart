import 'api_service.dart';
import '../models/user.dart';

class AuthService {
  Future<Map<String, dynamic>> register({
    required String name,
    String? phone,
    required String email,
    required String password,
  }) async {
    return await ApiService.post('/register', {
      'name': name,
      'phone': phone ?? '',
      'email': email,
      'password': password,
    }, requireAuth: false);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final res = await ApiService.post('/auth/verify-otp', {
      'email': email,
      'otp_code': otpCode,
    }, requireAuth: false);

    if (res['status'] == 'success' && res['data']?['token'] != null) {
      await ApiService.setToken(res['data']['token']);
    }

    return res;
  }

  Future<Map<String, dynamic>> resendOtp({required String email}) async {
    return await ApiService.post('/auth/resend-otp', {
      'email': email,
    }, requireAuth: false);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiService.post('/login', {
      'email': email,
      'password': password,
    }, requireAuth: false);

    if (res['status'] == 'success' && res['data']?['token'] != null) {
      await ApiService.setToken(res['data']['token']);
    }

    return res;
  }

  Future<UserModel?> getProfile() async {
    final res = await ApiService.get('/user');
    if (res['status'] == 'success' && res['data']?['user'] != null) {
      return UserModel.fromJson(res['data']['user']);
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await ApiService.post('/logout', {});
    } catch (_) {}
    await ApiService.removeToken();
  }
}
