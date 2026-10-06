import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String keyBaseUrl = 'api_base_url';
  
  // Live Production Server Base URL
  static String defaultBaseUrl = 'https://vidbez.com/api/v1';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(keyBaseUrl);
    // Auto-update to production https://vidbez.com/api/v1 if null or saved with localhost/127.0.0.1
    if (stored == null || stored.contains('127.0.0.1') || stored.contains('10.0.2.2') || stored.contains('localhost')) {
      stored = defaultBaseUrl;
      await prefs.setString(keyBaseUrl, defaultBaseUrl);
    }
    return stored;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBaseUrl, url.trim());
  }
}
