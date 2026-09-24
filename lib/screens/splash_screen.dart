import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showApiServerDialog() async {
    final currentUrl = await ApiConfig.getBaseUrl();
    _urlController.text = currentUrl;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('API Server Config', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Laravel API Base URL:\n• Android Emulator: http://10.0.2.2:8000/api/v1\n• Localhost: http://127.0.0.1:8000/api/v1\n• WiFi IP: http://192.168.x.x:8000/api/v1',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8000/api/v1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConfig.setBaseUrl(_urlController.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _checkAuth();
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bgDarkHeader, AppTheme.bgDarkBody],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                    child: const Icon(
                      Icons.record_voice_over,
                      size: 50,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MeetInt Audio',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Secure Audio Rooms & Meeting Hosting',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: IconButton(
                onPressed: _showApiServerDialog,
                icon: const Icon(Icons.settings, color: Colors.white54),
                tooltip: 'Server Settings',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
