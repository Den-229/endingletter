// Fichier de configuration Firebase.
//
// ⚠️ STUB de développement — À remplacer par le fichier généré par
// `flutterfire configure` pour pointer vers un vrai projet Firebase.
//
// Ce stub permet au projet de compiler sans dépendre d'un backend Firebase
// configuré. En l'état, les appels Firebase échoueront à l'exécution, mais
// l'app reste 100% utilisable hors-ligne (le dictionnaire local + tous les
// modes de jeu fonctionnent).
//
// Pour activer Firebase :
//   1. flutterfire configure
//   2. flutter pub run firebase_core:firebase_core_config
//   3. Le fichier ci-dessous sera régénéré automatiquement.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'REPLACE_WITH_REAL_API_KEY',
      appId: 'REPLACE_WITH_REAL_APP_ID',
      messagingSenderId: 'REPLACE_WITH_REAL_SENDER_ID',
      projectId: 'REPLACE_WITH_REAL_PROJECT_ID',
      storageBucket: 'REPLACE_WITH_REAL_BUCKET',
      authDomain: 'REPLACE_WITH_REAL_AUTH_DOMAIN',
    );
  }
}
