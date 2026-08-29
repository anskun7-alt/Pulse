import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PulseApp extends StatelessWidget {
  const PulseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PulseColors.themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Pulse',
          debugShowCheckedModeBanner: false,
          theme: PulseTheme.theme,
          home: const HomeScreen(),
        );
      },
    );
  }
}
