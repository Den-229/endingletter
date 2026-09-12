import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/auth_service.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'services/dictionary_local_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Ouvre la base SQLite et charge le dictionnaire en mémoire avant le
  // premier frame : la première partie peut ainsi valider les mots
  // instantanément (offline-first).
  await DatabaseService.instance.open();
  await DictionaryLocalService.instance.ensureLoaded();

  // Initialise Firebase Auth en arrière-plan : ne bloque pas le démarrage
  // si Firebase n'est pas configuré (le stub firebase_options.dart permet
  // au moins la compilation et l'exécution offline).
  // ignore: discarded_futures
  AuthService.instance.init().catchError((Object _) => null);

  runApp(const EndingLetterApp());
}

class EndingLetterApp extends StatelessWidget {
  const EndingLetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ending Letter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Violet 500
          secondary: Color(0xFFF59E0B), // Amber 500
          surface: Color(0xFF1E293B), // Slate 800
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
