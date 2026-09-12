/// Mode de jeu (utilisé par le contrôleur pour savoir s'il parle à un
/// transport distant ou s'il applique les coups localement).
///
/// - [passAndPlay] : deux joueurs sur le même téléphone, sans réseau.
/// - [solo]        : un humain contre une IA locale (joueur 2).
/// - [lanHost]     : joueur 1 héberge une partie TCP sur le LAN.
/// - [lanGuest]    : joueur 2 rejoint une partie TCP sur le LAN.
enum GameMode {
  passAndPlay,
  solo,
  lanHost,
  lanGuest,
}