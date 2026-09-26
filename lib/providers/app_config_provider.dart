import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class AppConfigProvider extends ChangeNotifier {
  String _appName = 'VidBez';
  String _companyName = 'VidBez Enterprise';
  String? _logoUrl;
  String _tagline = 'Enterprise Audio Meetings';
  bool _isLoading = false;

  String get appName => _appName;
  String get companyName => _companyName;
  String? get logoUrl => _logoUrl;
  String get tagline => _tagline;
  bool get isLoading => _isLoading;

  AppConfigProvider() {
    fetchAppConfig();
  }

  Future<void> fetchAppConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final res = await ApiService.get('/branding/public?url=${Uri.encodeComponent(baseUrl)}', requireAuth: false);

      if (res['status'] == 'success' && res['data']?['branding'] != null) {
        final b = res['data']['branding'];
        if (b['app_name'] != null && b['app_name'].toString().trim().isNotEmpty) {
          _appName = b['app_name'].toString().trim();
        }
        if (b['company_name'] != null && b['company_name'].toString().trim().isNotEmpty) {
          _companyName = b['company_name'].toString().trim();
        }
        _logoUrl = b['logo_url'];
        if (b['tagline'] != null && b['tagline'].toString().trim().isNotEmpty) {
          _tagline = b['tagline'].toString().trim();
        }
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }
}
