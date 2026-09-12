# Ending Letter

Jeu de chaîne de mots en Flutter : chaque joueur doit entrer un mot anglais
valide commençant par la dernière lettre du mot précédent.

## Caractéristiques

- 📚 **Dictionnaire 100 % local** : ~173 000 mots du projet ENABLE sont
  importés dans SQLite au premier lancement. Aucune connexion requise pour
  jouer.
- ☁️ **Synchronisation Firebase** : un administrateur peut publier une
  wordlist mise à jour dans Cloud Storage + Firestore ; n'importe quel
  utilisateur connecté peut déclencher une sync manuelle depuis le menu
  *Compte & Sync*.
- 🎮 **Trois modes de jeu** :
  - **Pass & Play** : deux joueurs sur le même téléphone.
  - **Solo contre IA** : vous jouez contre une IA locale qui choisit un mot
    au hasard pondéré par fréquence (mots rares = plus difficiles à placer).
  - **Multijoueur LAN** : deux téléphones sur le même Wi-Fi (ou en
    hotspot). Connexion TCP directe, sans Internet.
- ✨ **Polish** : animations `flutter_animate`, sons courts via
  `audioplayers`, thème dark violine/or.

## Architecture

```
lib/
├── main.dart              # bootstrap : ouvre SQLite + importe le seed
├── auth/                  # Firebase Auth + rôle admin (Firestore)
├── cloud/                 # Firestore + Storage (publication wordlist)
├── game/                  # GameController (4 modes) + transport abstrait
├── lan/                   # UDP broadcast discovery + TCP length-prefixed
│                          # socket (cf. README)
├── screens/               # splash / menu / jeu / LAN / compte / admin
├── services/              # SQLite + dictionnaire local + API fallback
├── shared/                # result types, connectivity, sound service
└── utils/                 # wordlist loader (seed, import/export JSON)
```

### Multijoueur LAN — détails techniques

La découverte utilise un **broadcast UDP** sur le port **45678** (durée de
balise : 2 s). Le host ouvre un `ServerSocket` sur un port TCP aléatoire
et inclut ce port dans la balise. Le guest écoute les balises, déduplique
par IP, et se connecte via TCP.

Format de balise (JSON, UTF-8, ≤ 512 octets) :

```json
{ "app": "endingletter", "version": 1, "name": "Alice", "port": 40123 }
```

Format des trames TCP (length-prefixed JSON) :

```
[4 octets BE longueur][utf-8 JSON][4 octets BE longueur][utf-8 JSON]…
```

Protocole applicatif (`lib/lan/lan_message.dart`) :

| Type          | Sens        | Description                          |
|---------------|-------------|--------------------------------------|
| `hello`       | guest→host  | premier contact, nom + sessionId     |
| `welcome`     | host→guest  | assigne `assignedPlayer = 2`         |
| `state`       | host→guest  | état autoritaire après chaque coup   |
| `move`        | guest→host  | proposition de mot                   |
| `moveAccepted`| host→guest  | confirmation + lettre suivante        |
| `moveRejected`| host→guest  | motif du refus                       |
| `giveUp`      | ↔           | abandon                              |
| `rematch`     | ↔           | nouvelle partie                      |
| `chat`        | ↔           | message texte (placeholder)          |
| `ping`/`pong` | ↔           | heartbeat (timeout après 3 pong ratés)|

### Permissions réseau

**Android** — `android/app/src/main/AndroidManifest.xml` :
- `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`,
  `CHANGE_WIFI_MULTICAST_STATE`
- `android:usesCleartextTraffic="true"` (TCP brut sur réseau local)

**iOS** — `ios/Runner/Info.plist` :
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices = [_endingletter._tcp]`

## Démarrage

```bash
flutter pub get
flutter run
```

Premier lancement : import du seed (~ 5–10 s), puis le menu apparaît.

### Tester la sync Firebase

1. Créer un projet Firebase, activer Authentication (email/password) et
   Firestore + Storage.
2. Renseigner `lib/firebase_options.dart` (FlutterFire CLI :
   `flutterfire configure`).
3. Sur la console Firestore, créer la collection `users/{uid}` avec un champ
   `role = "admin"` pour le compte admin.
4. Aller dans *Publier (admin)* et publier la wordlist.
5. Sur un autre téléphone, *Compte & Sync* → se connecter → *Synchroniser*.

### Tester le multijoueur LAN

1. Les deux téléphones sur le même Wi-Fi (ou l'un en hotspot).
2. Sur le téléphone 1 : *Multijoueur LAN* → *Héberger* — noter l'IP affichée.
3. Sur le téléphone 2 : *Multijoueur LAN* → *Rejoindre* — sélectionner
   l'hôte détecté. Si rien ne s'affiche (certains routeurs bloquent le
   broadcast), utiliser *Rejoindre par IP* et saisir l'IP + port notés à
   l'étape 2.
4. Le host commence (ou le guest, selon le protocole — ici c'est le host).
