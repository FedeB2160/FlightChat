// lib/features/onboarding/data/group_repository.dart — CRUD sulla tabella groups
import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../models/group_invite.dart';

class GroupRepository {
  final DatabaseService db;

  GroupRepository({required this.db});

  /// `role` e `'captain'` per chi crea il gruppo, `'member'` per chi si unisce.
  ///
  /// `groupName` esplicito ha la precedenza; altrimenti si usa quello che il QR
  /// trasporta nel campo `n`, che e la sola fonte per chi si unisce scansionando.
  Future<void> saveGroup(
    GroupInvite invite,
    String role, {
    String? groupName,
  }) async {
    final database = await db.database;
    final name = groupName?.trim();

    await database.insert(
      'groups',
      {
        'group_id': invite.groupId,
        'group_name': (name != null && name.isNotEmpty) ? name : invite.groupName,
        'encryption_key': invite.aesKey,
        't0': invite.t0,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'role': role,
      },
      // Il piano non indica una strategia: rientrare in un gruppo o rinominarlo
      // deve aggiornare il record, non fallire.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GroupInvite?> getGroup(String groupId) async {
    final database = await db.database;
    final rows = await database.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<GroupInvite>> getAllGroups() async {
    final database = await db.database;
    final rows = await database.query('groups', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  /// Serve a decifrare i messaggi del gruppo.
  Future<String?> getEncryptionKey(String groupId) async {
    final database = await db.database;
    final rows = await database.query(
      'groups',
      columns: ['encryption_key'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['encryption_key'] as String;
  }

  GroupInvite _fromRow(Map<String, Object?> row) => GroupInvite(
        groupId: row['group_id'] as String,
        aesKey: row['encryption_key'] as String,
        t0: row['t0'] as int,
        groupName: row['group_name'] as String?,
      );
}
