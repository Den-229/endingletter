import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/confetti_overlay.dart';
import 'car_models.dart';
import 'dr_parking_view.dart';
import 'asphalt_nitro_view.dart';

class NitroDrDriverScreen extends StatefulWidget {
  const NitroDrDriverScreen({super.key});

  @override
  State<NitroDrDriverScreen> createState() => _NitroDrDriverScreenState();
}

class _NitroDrDriverScreenState extends State<NitroDrDriverScreen> {
  DrivingGameMode _currentMode = DrivingGameMode.asphaltNitro;
  RacingVehicle _selectedVehicle = RacingVehicle.garage.first;
  bool _showVictory = false;
  String _victoryTitle = 'CHAMPION DU VOLANT ! 🏆';

  void _onLevelComplete() {
    setState(() {
      _showVictory = true;
      _victoryTitle = 'CRÉNEAU PARFAIT ! 🅿️';
    });
    FeedbackService.triggerSuccess();
    StorageService.saveHighScore('dr_parking', 100);
  }

  void _onCrash() {
    FeedbackService.triggerImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFFF0055),
        content: Text('💥 Crash sur l\'autoroute ! Réessayez en esquivant le trafic.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      showCelebration: _showVictory,
      title: _victoryTitle,
      subtitle: '+150 XP • Maîtrise automobile débloquée',
      onDismiss: () => setState(() => _showVictory = false),
      child: Scaffold(
        backgroundColor: const Color(0xFF070B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10172D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _currentMode == DrivingGameMode.asphaltNitro ? 'ASPHALT NITRO TURBO' : 'DR. PARKING CITY',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            // Sélecteur de véhicule
            PopupMenuButton<RacingVehicle>(
              icon: const Icon(Icons.directions_car, color: Color(0xFF00FFCC)),
              tooltip: 'Changer de véhicule',
              color: const Color(0xFF10172D),
              onSelected: (veh) {
                FeedbackService.triggerSelection();
                setState(() => _selectedVehicle = veh);
              },
              itemBuilder: (ctx) => RacingVehicle.garage.map((v) {
                final isSelected = v.id == _selectedVehicle.id;
                return PopupMenuItem(
                  value: v,
                  child: Row(
                    children: [
                      Icon(v.icon, color: v.primaryColor),
                      const SizedBox(width: 10),
                      Text(v.name, style: TextStyle(color: isSelected ? const Color(0xFF00FFCC) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Sélecteur de Mode en haut (Dr. Parking vs Asphalt Nitro)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF0C1224),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.flash_on, size: 16, color: Colors.black),
                      label: const Text('Asphalt Nitro (Vitesse)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: _currentMode == DrivingGameMode.asphaltNitro,
                      selectedColor: const Color(0xFF00F0FF),
                      labelStyle: TextStyle(
                        color: _currentMode == DrivingGameMode.asphaltNitro ? Colors.black : Colors.white70,
                      ),
                      onSelected: (_) => setState(() {
                        _currentMode = DrivingGameMode.asphaltNitro;
                        _showVictory = false;
                      }),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      avatar: const Icon(Icons.local_parking, size: 16, color: Colors.black),
                      label: const Text('Dr. Parking (Précision)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: _currentMode == DrivingGameMode.drParking,
                      selectedColor: const Color(0xFFFFD166),
                      labelStyle: TextStyle(
                        color: _currentMode == DrivingGameMode.drParking ? Colors.black : Colors.white70,
                      ),
                      onSelected: (_) => setState(() {
                        _currentMode = DrivingGameMode.drParking;
                        _showVictory = false;
                      }),
                    ),
                  ],
                ),
              ),

              // Vue active selon le mode choisi
              Expanded(
                child: _currentMode == DrivingGameMode.drParking
                    ? DrParkingView(
                        vehicle: _selectedVehicle,
                        onLevelComplete: _onLevelComplete,
                      )
                    : AsphaltNitroView(
                        vehicle: _selectedVehicle,
                        onCrash: _onCrash,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
