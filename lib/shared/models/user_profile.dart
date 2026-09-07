// lib/shared/models/user_profile.dart — User profile model with deterministic color palette and theme avatar icons
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class UserProfile {
  final String deviceId;
  final String nickname;
  final int avatarIconIndex;
  
  UserProfile({
    required this.deviceId,
    required this.nickname,
    required this.avatarIconIndex,
  });

  static const List<Color> avatarPalette = [
    Color(0xFF2563EB), Color(0xFF6366F1), Color(0xFF059669), Color(0xFFDC2626),
    Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFFE11D48),
  ];

  static const List<IconData> avatarIcons = [
    Icons.airplanemode_active,
    Icons.person,
    Icons.flight_takeoff,
    Icons.luggage,
    Icons.cloud,
    Icons.public,
    Icons.headphones,
    Icons.explore,
    Icons.card_travel,
    Icons.visibility,
    Icons.confirmation_number,
    Icons.star,
  ];

  factory UserProfile.create({required String nickname, int iconIndex = 0}) {
    return UserProfile(
      deviceId: const Uuid().v4(),
      nickname: nickname,
      avatarIconIndex: iconIndex,
    );
  }

  Color get color => avatarPalette[deviceId.hashCode.abs() % avatarPalette.length];
  IconData get icon => avatarIcons[avatarIconIndex % avatarIcons.length];
}
