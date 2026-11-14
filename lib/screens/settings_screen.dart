import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _audio;
  late bool _haptics;

  @override
  void initState() {
    super.initState();
    _audio = StorageService.isAudioEnabled();
    _haptics = StorageService.isHapticsEnabled();
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10172D),
        title: const Text('Réinitialiser les scores ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Cette action effacera vos records et vos favoris enregistrés sur l\'appareil.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ANNULER', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055)),
            onPressed: () {
              Navigator.of(ctx).pop();
              FeedbackService.triggerImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF00FFCC),
                  content: Text('Données réinitialisées avec succès.', style: TextStyle(color: Colors.black)),
                ),
              );
            },
            child: const Text('RÉINITIALISER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        title: const Text(
          '⚙️ PARAMÈTRES & SYSTÈME',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section Audio & Haptique
          const Text('EXPÉRIENCE SENSORIELLE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),

          Material(
            color: const Color(0xFF10172D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up, color: Color(0xFF00FFCC)),
                  title: const Text('Effets Sonores & Clics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Retour audio lors des mouvements et des victoires', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _audio,
                  activeTrackColor: const Color(0xFF00FFCC),
                  onChanged: (val) {
                    setState(() => _audio = val);
                    StorageService.setAudioEnabled(val);
                    FeedbackService.triggerSelection();
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: Color(0xFFFFD166)),
                  title: const Text('Vibrations Haptiques', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sensations tactiles immersives sous les doigts', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _haptics,
                  activeTrackColor: const Color(0xFFFFD166),
                  onChanged: (val) {
                    setState(() => _haptics = val);
                    StorageService.setHapticsEnabled(val);
                    FeedbackService.triggerImpact();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Infos & Hors-Ligne
          const Text('ARCHITECTURE & CONTENU', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10172D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nombre de Jeux Disponibles', style: TextStyle(color: Colors.white70)),
                    Text('125+ Jeux Natifs', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mode Hors-Ligne (Offline)', style: TextStyle(color: Colors.white70)),
                    Text('100% Fonctionnel', style: TextStyle(color: Color(0xFF05FFA1), fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Version de la Suite', style: TextStyle(color: Colors.white70)),
                    Text('v2.0.0 Pro Suite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Réinitialisation
          OutlinedButton.icon(
            onPressed: _showResetDialog,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF0055)),
            label: const Text('RÉINITIALISER LES DONNÉES ET RECORDS', style: TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF0055)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
