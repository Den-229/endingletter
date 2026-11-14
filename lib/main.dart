import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation du stockage des scores et paramètres
  await StorageService.init();

  // Optimisation de l'affichage mobile plein écran immersif
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NeoChromaApp());
}

class NeoChromaApp extends StatelessWidget {
  const NeoChromaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neo-Chroma Mobile Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060914),
        primaryColor: const Color(0xFF00FFCC),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFF00F0FF),
          tertiary: Color(0xFFFF007F),
          surface: Color(0xFF10142B),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
