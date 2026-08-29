import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/theme.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PulseApp extends StatelessWidget {
  const PulseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('settings_box').listenable(keys: ['theme_mode']),
      builder: (context, box, child) {
        final themeMode = box.get('theme_mode', defaultValue: 'Dark') as String;
        
        ThemeData theme;
        if (themeMode == 'AMOLED') {
          theme = PulseTheme.amoledTheme;
        } else if (themeMode == 'Creme') {
          theme = PulseTheme.cremeTheme;
        } else if (themeMode == 'Light') {
          theme = PulseTheme.lightTheme;
        } else {
          theme = PulseTheme.darkTheme; // Standard Dark
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Pulse',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const HomeScreen(),
        );
      },
    );
  }
}

