import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Fixed import
import 'providers/theme_provider.dart';
import 'notifications_service.dart';
import 'router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
var cloudinary = Cloudinary.fromStringUrl('cloudinary://385591396375353:xLsaxwieO44_tPNLulzCNrweET8@dfk7mskxv');

Future<bool> checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  if (isFirstLaunch) {
    await prefs.setBool('is_first_launch', false);
  }
  return isFirstLaunch;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  cloudinary.config.urlConfig.secure = true;
  await NotificationsService.initialize();
  
  final isFirstLaunch = await checkFirstLaunch();
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  
  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            title: 'Services App',
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,
          );
        },
      ),
    );
  }
}
