import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/app_config_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/livekit_room_provider.dart';
import 'providers/meeting_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';

import 'providers/wallet_provider.dart';
import 'providers/banner_notification_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ApiService.onSessionExpired = (message) {
    if (ApiService.isSessionDialogShowing) return;
    ApiService.isSessionDialogShowing = true;

    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Session Destroyed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            message.isNotEmpty
                ? message
                : 'Your login session was destroyed because your account logged in from another device.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final auth = context.mounted ? Provider.of<AuthProvider>(context, listen: false) : null;
                Navigator.of(dialogContext).pop();
                ApiService.isSessionDialogShowing = false;
                await ApiService.removeToken();
                try {
                  await auth?.logout();
                } catch (_) {}
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ApiService.isSessionDialogShowing = false;
    }
  };

  runApp(const BestRechargeApp());
}

class BestRechargeApp extends StatelessWidget {
  const BestRechargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => LiveKitRoomProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => BannerNotificationProvider()),
      ],
      child: Consumer<AppConfigProvider>(
        builder: (context, appConfig, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: '${appConfig.appName} Audio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
