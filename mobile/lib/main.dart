import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await ApiService.initSession();

  runApp(const SettlrApp());
}

class SettlrApp extends StatelessWidget {
  const SettlrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settlr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: SettlrColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SettlrColors.primary,
          primary: SettlrColors.primary,
        ),
        useMaterial3: true,
      ),
      home: ApiService.currentUser != null
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
