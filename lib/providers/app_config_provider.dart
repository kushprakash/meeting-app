import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class AppConfigProvider extends ChangeNotifier {
  String _appName = 'Best Recharge';
  String _companyName = 'Best Recharge Services';
  String? _logoUrl;
  String _tagline = 'Instant Recharge & Utility Payments';
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
        final String? serverName = b['app_name']?.toString().trim();
        if (serverName != null && serverName.isNotEmpty) {
          if (!serverName.toLowerCase().contains('vidbez') && !serverName.toLowerCase().contains('meetint')) {
            _appName = serverName;
          }
        }
        final String? serverCompany = b['company_name']?.toString().trim();
        if (serverCompany != null && serverCompany.isNotEmpty) {
          if (!serverCompany.toLowerCase().contains('vidbez') && !serverCompany.toLowerCase().contains('meetint')) {
            _companyName = serverCompany;
          }
        }
        _logoUrl = b['logo_url'];
        final String? serverTagline = b['tagline']?.toString().trim();
        if (serverTagline != null && serverTagline.isNotEmpty) {
          if (!serverTagline.toLowerCase().contains('webrtc')) {
            _tagline = serverTagline;
          }
        }
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }
}
