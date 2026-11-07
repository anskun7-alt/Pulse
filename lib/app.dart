import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'theme/logo.dart';
import 'theme/theme.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PulseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class PulseApp extends StatefulWidget {
  final String? initialFilePath;
  const PulseApp({Key? key, this.initialFilePath}) : super(key: key);

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    PulseColors.notifyPlatformBrightnessChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PulseColors.themeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: PulseTypography.fontStyleNotifier,
          builder: (context, fontStyle, _) {
            return ValueListenableBuilder<String>(
              valueListenable: PulseLogo.logoStyleNotifier,
              builder: (context, logoStyle, _) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  scaffoldMessengerKey: scaffoldMessengerKey,
                  scrollBehavior: PulseScrollBehavior(),
                  title: 'Pulse',
                  debugShowCheckedModeBanner: false,
                  theme: PulseTheme.theme,
                  home: SplashScreen(initialFilePath: widget.initialFilePath),
                );
              },
            );
          },
        );
      },
    );
  }
}
