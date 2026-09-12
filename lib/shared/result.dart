/// Résultat typé pour les opérations sync (cloud, LAN).
///
/// Évite de lancer des exceptions pour des états attendus (offline, déjà à
/// jour, vérification échouée). L'UI peut donc afficher un message clair.
sealed class SyncResult<T> {
  const SyncResult();

  /// Helper: exécute [body] dans un try/catch et convertit en [SyncFailure].
  static Future<SyncResult<T>> guard<T>(Future<T> Function() body) async {
    try {
      return SyncSuccess(await body());
    } catch (e) {
      return SyncFailure<T>(e.toString());
    }
  }
}

class SyncSuccess<T> extends SyncResult<T> {
  const SyncSuccess(this.data);
  final T data;
}

class SyncAlreadyUpToDate<T> extends SyncResult<T> {
  const SyncAlreadyUpToDate(this.remoteSha256);
  final String remoteSha256;
}

class SyncOffline<T> extends SyncResult<T> {
  const SyncOffline();
}

class SyncVerificationFailed<T> extends SyncResult<T> {
  const SyncVerificationFailed(this.reason);
  final String reason;
}

class SyncFailure<T> extends SyncResult<T> {
  const SyncFailure(this.message);
  final String message;
}