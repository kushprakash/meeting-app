import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/app_config_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/livekit_room_provider.dart';
import 'providers/meeting_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeetIntApp());
}

class MeetIntApp extends StatelessWidget {
  const MeetIntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => LiveKitRoomProvider()),
      ],
      child: Consumer<AppConfigProvider>(
        builder: (context, appConfig, _) {
          return MaterialApp(
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
