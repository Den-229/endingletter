import 'package:flutter/material.dart';

enum DrivingGameMode { drParking, asphaltNitro }

class RacingVehicle {
  final String id;
  final String name;
  final Color primaryColor;
  final double topSpeed;
  final double handling;
  final double acceleration;
  final IconData icon;

  const RacingVehicle({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.topSpeed,
    required this.handling,
    required this.acceleration,
    required this.icon,
  });

  static const List<RacingVehicle> garage = [
    RacingVehicle(
      id: 'gt_cyber',
      name: 'Apex GT Cyber',
      primaryColor: Color(0xFF00FFCC),
      topSpeed: 280,
      handling: 0.9,
      acceleration: 0.85,
      icon: Icons.electric_car,
    ),
    RacingVehicle(
      id: 'nitro_venom',
      name: 'Venom Hyper-Sport',
      primaryColor: Color(0xFFFF0055),
      topSpeed: 340,
      handling: 0.8,
      acceleration: 0.95,
      icon: Icons.sports_motorsports,
    ),
    RacingVehicle(
      id: 'city_cruiser',
      name: 'Dr. Cruiser Sedan',
      primaryColor: Color(0xFFFFD166),
      topSpeed: 180,
      handling: 0.98,
      acceleration: 0.70,
      icon: Icons.directions_car,
    ),
  ];
}
