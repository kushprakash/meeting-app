import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String keyBaseUrl = 'api_base_url';
  
  // Default base URL (Supports Android Emulator 10.0.2.2, localhost, or custom LAN IP)
  static String defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBaseUrl, url.trim());
  }
}
