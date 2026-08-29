import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _uuid = Uuid();

  Database? _db;
  final _pendingController = StreamController<int>.broadcast();

  Stream<int> get pendingCountChanges => _pendingController.stream;

  Future<void> initialize() async {
    if (_db != null) return;

    _db = await openDatabase(
      'salesapp.db',
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createBaseTables(db);
        await _createTrackingTable(db);
        await _createCacheTable(db);
        await _createOfflineQueueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTrackingTable(db);
        }
        if (oldVersion < 3) {
          await _createCacheTable(db);
        }

        if (oldVersion < 4) {
          await _createOfflineQueueTables(db);
        }
      },
    );

    await _emitPendingCount();
  }

  Future<void> _createBaseTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE enquiries (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        enquiry_type TEXT NOT NULL,
        contact_person TEXT NOT NULL,
        phone TEXT,
        company TEXT,
        requirement TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_status (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        work_date TEXT NOT NULL,
        dealers_visited INTEGER NOT NULL DEFAULT 0,
        orders INTEGER NOT NULL DEFAULT 0,
        summary TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(employee_id, work_date)
      )
    ''');

    await db.execute('''
      CREATE TABLE work_sessions (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        work_date TEXT NOT NULL,
        check_in_at TEXT NOT NULL,
        check_out_at TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(employee_id, work_date)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_outbox (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sync_outbox_status_created '
      'ON sync_outbox(status, created_at)',
    );
  }

  Future<void> _createTrackingTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tracking_points (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        work_date TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        speed REAL,
        recorded_at TEXT NOT NULL,
        segment_distance_m REAL NOT NULL DEFAULT 0,
        total_distance_m REAL NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tracking_points_day '
      'ON tracking_points(employee_id, work_date, recorded_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tracking_points_sync '
      'ON tracking_points(synced, recorded_at)',
    );
  }

  // BRIXTA_ROW_OFFLINE_QUEUE_V1
  //
  // One offline mutation == one SQLite row.
  //
  // This prevents queue enqueue cost from growing with the
  // complete offline backlog.
  Future<void> _createOfflineQueueTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_queue_items (
        id TEXT PRIMARY KEY,
        queue_name TEXT NOT NULL,
        scope TEXT NOT NULL,
        method TEXT,
        path TEXT,
        payload_json TEXT NOT NULL,
        client_mutation_id TEXT,
        produces_record_key TEXT,
        record_reference_key TEXT,
        queued_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_offline_queue_order '
      'ON offline_queue_items(queue_name, scope, queued_at)',
    );

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_offline_queue_mutation '
      'ON offline_queue_items('
      'queue_name, scope, client_mutation_id'
      ')',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_queue_resolutions (
        queue_name TEXT NOT NULL,
        scope TEXT NOT NULL,
        reference_key TEXT NOT NULL,
        record_id TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(queue_name, scope, reference_key)
      )
    ''');
  }

  Future<void> _createCacheTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_cache (
        cache_key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> putCache(String key, Object? value) async {
    await db.insert('app_cache', {
      'cache_key': key,
      'value_json': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Object?> getCache(String key) async {
    final rows = await db.query(
      'app_cache',
      columns: ['value_json'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['value_json']! as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeCache(String key) async {
    await db.delete('app_cache', where: 'cache_key = ?', whereArgs: [key]);
  }

  Future<bool> enqueueOfflineQueueItem({
    required String queueName,
    required String scope,
    String? method,
    String? path,
    required Map<String, dynamic> payload,
    String? clientMutationId,
    String? producesRecordKey,
    String? recordReferenceKey,
    String? queuedAt,
  }) async {
    final normalizedMutationId =
        clientMutationId == null || clientMutationId.trim().isEmpty
        ? null
        : clientMutationId.trim();

    final inserted = await db.insert('offline_queue_items', {
      'id': newId(),
      'queue_name': queueName,
      'scope': scope,
      'method': method,
      'path': path,
      'payload_json': jsonEncode(payload),
      'client_mutation_id': normalizedMutationId,
      'produces_record_key': producesRecordKey,
      'record_reference_key': recordReferenceKey,
      'queued_at': queuedAt ?? DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return inserted != 0;
  }

  Future<int> offlineQueueCount({
    required String queueName,
    required String scope,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM offline_queue_items
      WHERE queue_name = ? AND scope = ?
      ''',
      [queueName, scope],
    );

    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<Map<String, Object?>>> offlineQueueBatch({
    required String queueName,
    required String scope,
    int limit = 100,
  }) {
    return db.query(
      'offline_queue_items',
      where: 'queue_name = ? AND scope = ?',
      whereArgs: [queueName, scope],
      orderBy: 'queued_at ASC, id ASC',
      limit: limit,
    );
  }

  Future<void> deleteOfflineQueueItems(Iterable<String> ids) async {
    final values = ids.toList(growable: false);

    if (values.isEmpty) return;

    final placeholders = List.filled(values.length, '?').join(',');

    await db.delete(
      'offline_queue_items',
      where: 'id IN ($placeholders)',
      whereArgs: values,
    );
  }

  Future<String?> offlineQueueResolution({
    required String queueName,
    required String scope,
    required String referenceKey,
  }) async {
    final rows = await db.query(
      'offline_queue_resolutions',
      columns: ['record_id'],
      where: 'queue_name = ? AND scope = ? AND reference_key = ?',
      whereArgs: [queueName, scope, referenceKey],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return rows.first['record_id']?.toString();
  }

  Future<void> putOfflineQueueResolution({
    required String queueName,
    required String scope,
    required String referenceKey,
    required String recordId,
  }) async {
    await db.insert('offline_queue_resolutions', {
      'queue_name': queueName,
      'scope': scope,
      'reference_key': referenceKey,
      'record_id': recordId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Database get db {
    final value = _db;
    if (value == null) {
      throw StateError('AppDatabase.initialize() must be called first.');
    }
    return value;
  }

  String newId() => _uuid.v4();

  Future<void> saveTrackingPoint({
    required String employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required DateTime recordedAt,
    required double segmentDistanceM,
    required double totalDistanceM,
  }) async {
    await db.insert('tracking_points', {
      'id': newId(),
      'employee_id': employeeId,
      'work_date': _localDateKey(recordedAt.toLocal()),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'segment_distance_m': segmentDistanceM,
      'total_distance_m': totalDistanceM,
      'synced': 0,
    });
  }

  Future<List<Map<String, Object?>>> unsyncedTrackingPoints({int limit = 100}) {
    return db.query(
      'tracking_points',
      where: 'synced = 0',
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
  }

  // BRIXTA_TRACKING_BATCH_ACK_V1
  Future<void> markTrackingPointsSynced(Iterable<String> ids) async {
    final values = ids.toList(growable: false);

    if (values.isEmpty) return;

    final placeholders = List.filled(values.length, '?').join(',');

    await db.update(
      'tracking_points',
      {'synced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: values,
    );
  }

  // BRIXTA_TRACKING_RETENTION_V1
  //
  // Unsynced route evidence is NEVER deleted.
  //
  // Only server-acknowledged points older than the
  // retention window are eligible for cleanup.
  Future<int> pruneSyncedTrackingPoints({
    Duration retention = const Duration(days: 30),
  }) {
    final cutoff = DateTime.now().toUtc().subtract(retention).toIso8601String();

    return db.delete(
      'tracking_points',
      where:
          'synced = 1 '
          'AND recorded_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<double> todayDistanceKm(String employeeId) async {
    final rows = await db.rawQuery(
      '''
      SELECT MAX(total_distance_m) AS distance
      FROM tracking_points
      WHERE employee_id = ? AND work_date = ?
      ''',
      [employeeId, _localDateKey(DateTime.now())],
    );
    final value = rows.first['distance'];
    return ((value as num?)?.toDouble() ?? 0) / 1000;
  }

  Future<Map<String, Object?>?> lastTrackingPoint(String employeeId) async {
    final rows = await db.query(
      'tracking_points',
      where: 'employee_id = ? AND work_date = ?',
      whereArgs: [employeeId, _localDateKey(DateTime.now())],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveEnquiry({
    required String employeeId,
    required String enquiryType,
    required String contactPerson,
    required String phone,
    required String company,
    required String requirement,
  }) async {
    final id = newId();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'id': id,
      'employee_id': employeeId,
      'enquiry_type': enquiryType,
      'contact_person': contactPerson,
      'phone': phone,
      'company': company,
      'requirement': requirement,
      'created_at': now,
      'updated_at': now,
    };

    await db.transaction((txn) async {
      await txn.insert('enquiries', payload);
      await _queue(
        txn,
        entityType: 'enquiry',
        entityId: id,
        operation: 'upsert',
        payload: payload,
      );
    });
    await _emitPendingCount();
  }

  Future<void> saveDailyStatus({
    required String employeeId,
    required int dealersVisited,
    required int orders,
    required String summary,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final workDate = _localDateKey(DateTime.now());
    final existing = await db.query(
      'daily_status',
      columns: ['id', 'created_at'],
      where: 'employee_id = ? AND work_date = ?',
      whereArgs: [employeeId, workDate],
      limit: 1,
    );

    final id = existing.isEmpty ? newId() : existing.first['id']! as String;
    final createdAt = existing.isEmpty
        ? now
        : existing.first['created_at']! as String;

    final payload = <String, Object?>{
      'id': id,
      'employee_id': employeeId,
      'work_date': workDate,
      'dealers_visited': dealersVisited,
      'orders': orders,
      'summary': summary,
      'created_at': createdAt,
      'updated_at': now,
    };

    await db.transaction((txn) async {
      await txn.insert(
        'daily_status',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _queue(
        txn,
        entityType: 'daily_status',
        entityId: id,
        operation: 'upsert',
        payload: payload,
      );
    });
    await _emitPendingCount();
  }

  Future<Map<String, Object?>?> todayWorkSession(String employeeId) async {
    final rows = await db.query(
      'work_sessions',
      where: 'employee_id = ? AND work_date = ?',
      whereArgs: [employeeId, _localDateKey(DateTime.now())],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>> checkIn(String employeeId) async {
    final existing = await todayWorkSession(employeeId);
    if (existing != null) return existing;

    final id = newId();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'id': id,
      'employee_id': employeeId,
      'work_date': _localDateKey(DateTime.now()),
      'check_in_at': now,
      'check_out_at': null,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    };

    await db.transaction((txn) async {
      await txn.insert('work_sessions', payload);
      await _queue(
        txn,
        entityType: 'work_session',
        entityId: id,
        operation: 'upsert',
        payload: payload,
      );
    });
    await _emitPendingCount();
    return payload;
  }

  Future<Map<String, Object?>> checkOut(String employeeId) async {
    final existing = await todayWorkSession(employeeId);
    if (existing == null) {
      throw StateError('No work session exists for today.');
    }
    if (existing['status'] == 'completed') return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = Map<String, Object?>.from(existing)
      ..['check_out_at'] = now
      ..['status'] = 'completed'
      ..['updated_at'] = now;

    await db.transaction((txn) async {
      await txn.update(
        'work_sessions',
        {'check_out_at': now, 'status': 'completed', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      await _queue(
        txn,
        entityType: 'work_session',
        entityId: existing['id']! as String,
        operation: 'upsert',
        payload: updated,
      );
    });

    await _emitPendingCount();
    return updated;
  }

  Future<int> pendingCount() async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_outbox WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, Object?>>> pendingBatch({int limit = 100}) async {
    return db.query(
      'sync_outbox',
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> markAcknowledged(Iterable<String> eventIds) async {
    final ids = eventIds.toList(growable: false);
    if (ids.isEmpty) return;

    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
      }
    });

    await _emitPendingCount();
  }

  Future<void> markSyncFailure(String eventId, Object error) async {
    final rows = await db.query(
      'sync_outbox',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as int? ?? 0) + 1;
    await db.update(
      'sync_outbox',
      {'attempts': attempts, 'last_error': error.toString()},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> _queue(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await txn.insert('sync_outbox', {
      'id': newId(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
      'status': 'pending',
    });
  }

  Future<void> _emitPendingCount() async {
    if (_pendingController.isClosed) return;
    _pendingController.add(await pendingCount());
  }

  String _localDateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
