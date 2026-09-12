import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Indique si l'appareil a une connectivité Internet.
///
/// `Stream<bool> get online` émet `true` dès que le device a au moins une
/// interface réseau active (wifi, cellulaire, ethernet…). Note : avoir un
/// réseau ne garantit pas d'avoir Internet (ex. portail captif) — on s'appuie
/// ensuite sur le code retour HTTP pour détecter ce cas.
class ConnectivityGate {
  ConnectivityGate._();
  static final ConnectivityGate instance = ConnectivityGate._();

  final Connectivity _connectivity = Connectivity();

  /// Lecture ponctuelle.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream continu (re-émet l'état actuel à chaque souscription).
  Stream<bool> get online {
    return _connectivity.onConnectivityChanged.map((results) {
      final isUp = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (kDebugMode) {
        debugPrint('🌐 Connectivité: $isUp (raw=$results)');
      }
      return isUp;
    });
  }
}