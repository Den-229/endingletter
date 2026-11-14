import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_chroma_games/main.dart';
import 'package:neo_chroma_games/games/words/ending_letter/ending_letter_screen.dart';
import 'package:neo_chroma_games/games/racing/nitro_dr_driver/nitro_dr_driver_screen.dart';
import 'package:neo_chroma_games/games/sports/football/football_menu_screen.dart';
import 'package:neo_chroma_games/games/sports/football/football_match_screen.dart';
import 'package:neo_chroma_games/games/sports/football/football_league_screen.dart';
import 'package:neo_chroma_games/games/sports/football/football_training_screen.dart';
import 'package:neo_chroma_games/screens/multiplayer_hub_screen.dart';
import 'package:neo_chroma_games/screens/competitions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OmniGames Mega 125+ smoke test & games presence', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NeoChromaApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('OMNI-GAMES MEGA'), findsOneWidget);
    expect(find.text('UNO Classic & IA'), findsOneWidget);
    expect(find.text('Blackjack 21 Royale'), findsOneWidget);
    expect(find.text('Échecs & IA'), findsOneWidget);

    // Vérifier la présence des nouveaux Hubs Multijoueur & Compétitions
    expect(find.text('Multijoueur'), findsWidgets);
    expect(find.text('Compétitions'), findsWidgets);

    // Vérifier la présence du cadeau quotidien
    expect(find.textContaining('CADEAU DU JOUR'), findsOneWidget);
  });

  testWidgets('Narrow mobile screen layout does not overflow', (WidgetTester tester) async {
    // Teste la taille exacte rapportée dans le log utilisateur (largeur 443px)
    tester.view.physicalSize = const Size(443, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NeoChromaApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('OMNI-GAMES MEGA'), findsOneWidget);
    expect(tester.takeException(), isNull); // Aucune exception RenderFlex overflow
  });

  testWidgets('Landscape / Desktop 1280x664 screen does not overflow', (WidgetTester tester) async {
    // Teste la taille exacte rapportée dans l'erreur RenderFlex (1280x664)
    tester.view.physicalSize = const Size(1280, 664);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NeoChromaApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('OMNI-GAMES MEGA'), findsOneWidget);
    expect(tester.takeException(), isNull); // Aucune exception RenderFlex overflow
  });

  testWidgets('Ending Letter Word Chain screen renders and validates words', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: EndingLetterScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('ENDING LETTER'), findsOneWidget);
    expect(find.text('PROCHAINE LETTRE OBLIGATOIRE'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Entrer un mot
    await tester.enterText(find.byType(TextField), 'APPLE');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('APPLE'), findsOneWidget);
  });

  testWidgets('Nitro Dr. Driver screen toggles between Dr. Parking and Asphalt Nitro', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: NitroDrDriverScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('ASPHALT NITRO'), findsOneWidget);
    expect(find.textContaining('Dr. Parking'), findsOneWidget);
    expect(find.textContaining('Asphalt Nitro'), findsOneWidget);

    // Basculer sur Dr. Parking
    await tester.tap(find.textContaining('Dr. Parking'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('DR. PARKING CITY'), findsOneWidget);
  });

  testWidgets('Football PES Pro Striker menu and match launch', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: FootballMenuScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PES PRO STRIKER 2026'), findsOneWidget);
    expect(find.text('LANCER LE MATCH'), findsOneWidget);

    // Lancement du match
    await tester.tap(find.text('LANCER LE MATCH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FootballMatchScreen), findsOneWidget);
    expect(find.text('TIR'), findsOneWidget);
    expect(find.text('PASSE'), findsOneWidget);
    expect(find.text('SPRINT'), findsOneWidget);
  });

  testWidgets('Multiplayer Hub and Competitions Tournaments render smoothly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: MultiplayerHubScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('HUB MULTIJOUEUR'), findsOneWidget);
    expect(find.text('LANCER RECHERCHE RAPIDE'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: CompetitionsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('COMPÉTITIONS & TOURNOIS'), findsOneWidget);
    expect(find.textContaining('TABLEAU DU TOURNOI'), findsOneWidget);
  });

  testWidgets('Football League and Training screens render properly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: FootballLeagueScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('LIGUE DES CHAMPIONS PRO'), findsOneWidget);
    expect(find.textContaining('CLASSEMENT GÉNÉRAL'), findsOneWidget);
    expect(find.textContaining('DISPUTER LA JOURNÉE'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: FootballTrainingScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TIRS AU BUT & COUPS FRANCS'), findsOneWidget);
    expect(find.text('SCORE TOTAL'), findsOneWidget);
    expect(find.textContaining('GLISSEZ LE DOIGT'), findsOneWidget);
  });
}
