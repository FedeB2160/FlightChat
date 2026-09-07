// lib/features/onboarding/data/user_profile_repository.dart — CRUD sulla tabella user_profiles
import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../../../shared/models/user_profile.dart';

class UserProfileRepository {
  final DatabaseService db;

  UserProfileRepository({required this.db});

  /// DECISION: `isLocal` non e nella firma del piano, ma la colonna `is_local`
  /// e l'unico modo per rendere implementabile `getLocalProfile()`.
  /// Salvando il profilo locale il flag viene azzerato sugli altri, cosi resta unico.
  Future<void> saveProfile(UserProfile profile, {bool isLocal = false}) async {
    final database = await db.database;

    await database.transaction((txn) async {
      if (isLocal) {
        await txn.update(
          'user_profiles',
          {'is_local': 0},
          where: 'is_local = 1 AND device_id != ?',
          whereArgs: [profile.deviceId],
        );
      }

      await txn.insert(
        'user_profiles',
        {
          'device_id': profile.deviceId,
          'nickname': profile.nickname,
          'avatar_icon_index': profile.avatarIconIndex,
          'is_local': isLocal ? 1 : 0,
        },
        // Cambiare nickname o avatar deve aggiornare il record esistente.
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Crea o aggiorna il profilo del dispositivo **riusando il `deviceId` esistente**.
  ///
  /// DECISION: metodo non previsto dal piano. Senza, ogni passaggio da onboarding
  /// genererebbe un `deviceId` nuovo — il difetto D17 dell'audit di Fase 1 — e
  /// l'identita del nodo cambierebbe sotto i piedi alla mesh di Fase 3.
  Future<UserProfile> saveLocalProfile({
    required String nickname,
    required int iconIndex,
  }) async {
    final existing = await getLocalProfile();
    final profile = existing == null
        ? UserProfile.create(nickname: nickname, iconIndex: iconIndex)
        : UserProfile(
            deviceId: existing.deviceId,
            nickname: nickname,
            avatarIconIndex: iconIndex,
          );

    await saveProfile(profile, isLocal: true);
    return profile;
  }

  Future<UserProfile?> getProfile(String deviceId) async {
    final database = await db.database;
    final rows = await database.query(
      'user_profiles',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<UserProfile?> getLocalProfile() async {
    final database = await db.database;
    final rows = await database.query(
      'user_profiles',
      where: 'is_local = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Ultimo `time_delta` a cui il nodo e stato visto. Lo alimentera la mesh.
  Future<void> updateLastSeen(String deviceId, int timeDelta) async {
    final database = await db.database;
    await database.update(
      'user_profiles',
      {'last_seen_delta': timeDelta},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  UserProfile _fromRow(Map<String, Object?> row) => UserProfile(
        deviceId: row['device_id'] as String,
        nickname: row['nickname'] as String,
        avatarIconIndex: row['avatar_icon_index'] as int,
      );
}
