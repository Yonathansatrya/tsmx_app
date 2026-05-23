import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: const TMSXLogisticsApp(),
    ),
  );
}

class TMSXLogisticsApp extends StatelessWidget {
  const TMSXLogisticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMSX',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accentYellow,
          surface: Colors.white,
        ),

        scaffoldBackgroundColor: AppColors.background,

        textTheme: GoogleFonts.hankenGroteskTextTheme(
          Theme.of(context).textTheme,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return AppColors.softGreen;
          }),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}
