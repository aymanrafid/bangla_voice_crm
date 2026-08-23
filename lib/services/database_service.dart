// lib/services/database_service.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_alert.dart';
import '../models/app_user.dart';
import '../models/field_report.dart';
import '../models/field_visit.dart';
import '../models/gps_log.dart';
import '../models/lead.dart';
import '../models/lead_field_change.dart';
import '../models/lead_update_history.dart';
import '../models/meeting.dart';
import '../models/report_image.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bangla_crm.db');
    return openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createLeadsTable(db);
        await _createLeadUpdateHistoryTable(db);
        await _createUsersTable(db);
        await _createMeetingsTable(db);
        await _createFieldVisitsTable(db);
        await _createFieldReportsTable(db);
        await _createReportImagesTable(db);
        await _createGpsLogsTable(db);
        await _createAlertsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureLeadsColumns(db, _intelligenceColumns);
        }
        if (oldVersion < 3) {
          await _ensureLeadsColumns(db, _surveyColumns);
        }
        if (oldVersion < 4) {
          await _createLeadUpdateHistoryTable(db);
        }
        if (oldVersion < 5) {
          await _ensureLeadsColumns(db, _assignmentColumns);
        }
        if (oldVersion < 6) {
          await _createUsersTable(db);
          await _createMeetingsTable(db);
          await _createFieldVisitsTable(db);
          await _createFieldReportsTable(db);
          await _createReportImagesTable(db);
          await _createGpsLogsTable(db);
          await _createAlertsTable(db);
        }
        if (oldVersion < 7) {
          await _ensureLeadsSchema(db);
          await _createLeadUpdateHistoryTable(db);
          await _createUsersTable(db);
          await _createMeetingsTable(db);
          await _createFieldVisitsTable(db);
          await _createFieldReportsTable(db);
          await _createReportImagesTable(db);
          await _createGpsLogsTable(db);
          await _createAlertsTable(db);
        }
        if (oldVersion < 8) {
          await _ensureUsersSchema(db);
        }
        if (oldVersion < 9) {
          await _ensureUsersSchema(db);
        }
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );
  }

  static const Map<String, String> _intelligenceColumns = {
    'intent': "TEXT DEFAULT 'General Inquiry'",
    'sentiment': "TEXT DEFAULT 'Neutral'",
    'priority': "TEXT DEFAULT 'Normal'",
    'leadScore': 'INTEGER DEFAULT 50',
    'aiSummary': "TEXT DEFAULT ''",
    'nextAction': "TEXT DEFAULT ''",
  };

  static const Map<String, String> _surveyColumns = {
    'latitude': 'REAL',
    'longitude': 'REAL',
    'surveyStatus': "TEXT DEFAULT 'Not Started'",
    'surveyStartedAt': "TEXT DEFAULT ''",
    'surveyArrivedAt': "TEXT DEFAULT ''",
    'surveyDistanceMeters': 'REAL',
    'surveyNote': "TEXT DEFAULT ''",
  };

  static const Map<String, String> _assignmentColumns = {
    'assignedEmployeeId': 'INTEGER',
    'assignedEmployeeName': "TEXT DEFAULT ''",
    'assignedEmployeeExternalId': "TEXT DEFAULT ''",
    'version': 'INTEGER DEFAULT 1',
  };

  Future<void> _ensureSchema(Database db) async {
    await _ensureLeadsSchema(db);
    await _ensureUsersSchema(db);
    await _createLeadUpdateHistoryTable(db);
    await _createUsersTable(db);
    await _createMeetingsTable(db);
    await _createFieldVisitsTable(db);
    await _createFieldReportsTable(db);
    await _createReportImagesTable(db);
    await _createGpsLogsTable(db);
    await _createAlertsTable(db);
  }

  Future<void> _ensureLeadsSchema(Database db) async {
    await _ensureLeadsColumns(db, {
      ..._intelligenceColumns,
      ..._surveyColumns,
      ..._assignmentColumns,
    });
  }

  Future<void> _ensureUsersSchema(Database db) async {
    final existingColumns = await _getColumnNames(db, 'users');
    if (!existingColumns.contains('externalId')) {
      await db
          .execute("ALTER TABLE users ADD COLUMN externalId TEXT DEFAULT ''");
    }
    if (!existingColumns.contains('companyExternalId')) {
      await db.execute(
          "ALTER TABLE users ADD COLUMN companyExternalId TEXT DEFAULT ''");
    }
    if (!existingColumns.contains('companyName')) {
      await db
          .execute("ALTER TABLE users ADD COLUMN companyName TEXT DEFAULT ''");
    }
    if (!existingColumns.contains('companySlug')) {
      await db
          .execute("ALTER TABLE users ADD COLUMN companySlug TEXT DEFAULT ''");
    }
  }

  Future<void> _ensureLeadsColumns(
      Database db, Map<String, String> columns) async {
    final existingColumns = await _getColumnNames(db, 'leads');
    for (final entry in columns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
            'ALTER TABLE leads ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<Set<String>> _getColumnNames(Database db, String tableName) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
    return tableInfo.map((column) => column['name'] as String).toSet();
  }

  Future<void> _createLeadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE leads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leadId TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        leadType TEXT,
        name TEXT,
        phone TEXT,
        address TEXT,
        location TEXT,
        productInterest TEXT,
        transcript TEXT,
        status TEXT DEFAULT 'New',
        confidence INTEGER DEFAULT 0,
        intent TEXT DEFAULT 'General Inquiry',
        sentiment TEXT DEFAULT 'Neutral',
        priority TEXT DEFAULT 'Normal',
        leadScore INTEGER DEFAULT 50,
        aiSummary TEXT DEFAULT '',
        nextAction TEXT DEFAULT '',
        latitude REAL,
        longitude REAL,
        surveyStatus TEXT DEFAULT 'Not Started',
        surveyStartedAt TEXT DEFAULT '',
        surveyArrivedAt TEXT DEFAULT '',
        surveyDistanceMeters REAL,
        surveyNote TEXT DEFAULT '',
        assignedEmployeeId INTEGER,
        assignedEmployeeName TEXT DEFAULT '',
        assignedEmployeeExternalId TEXT DEFAULT '',
        version INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _createLeadUpdateHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lead_update_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leadDbId INTEGER NOT NULL,
        leadId TEXT NOT NULL,
        fieldKey TEXT NOT NULL,
        fieldLabel TEXT NOT NULL,
        oldValue TEXT DEFAULT '',
        newValue TEXT DEFAULT '',
        changedAt TEXT NOT NULL,
        changedBy TEXT NOT NULL,
        sourceType TEXT DEFAULT 'voice_update',
        sourceTranscript TEXT DEFAULT '',
        FOREIGN KEY (leadDbId) REFERENCES leads(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        externalId TEXT DEFAULT '',
        companyExternalId TEXT DEFAULT '',
        companyName TEXT DEFAULT '',
        companySlug TEXT DEFAULT '',
        username TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        role TEXT NOT NULL,
        fullName TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMeetingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meetings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        leadDbId INTEGER NOT NULL,
        leadId TEXT NOT NULL,
        clientName TEXT NOT NULL,
        location TEXT NOT NULL,
        scheduledAt TEXT NOT NULL,
        notes TEXT DEFAULT '',
        employeeId INTEGER NOT NULL,
        employeeName TEXT NOT NULL,
        status TEXT DEFAULT 'Scheduled',
        createdAt TEXT NOT NULL,
        adminNotifiedAt TEXT DEFAULT '',
        FOREIGN KEY (leadDbId) REFERENCES leads(id) ON DELETE CASCADE,
        FOREIGN KEY (employeeId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createFieldVisitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS field_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meetingId INTEGER NOT NULL,
        leadDbId INTEGER NOT NULL,
        leadId TEXT NOT NULL,
        employeeId INTEGER NOT NULL,
        employeeName TEXT NOT NULL,
        checkInAt TEXT NOT NULL,
        checkInLat REAL NOT NULL,
        checkInLng REAL NOT NULL,
        checkOutAt TEXT DEFAULT '',
        checkOutLat REAL,
        checkOutLng REAL,
        durationMinutes INTEGER DEFAULT 0,
        status TEXT DEFAULT 'Checked In',
        FOREIGN KEY (meetingId) REFERENCES meetings(id) ON DELETE CASCADE,
        FOREIGN KEY (leadDbId) REFERENCES leads(id) ON DELETE CASCADE,
        FOREIGN KEY (employeeId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createFieldReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS field_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meetingId INTEGER NOT NULL,
        visitId INTEGER NOT NULL,
        leadDbId INTEGER NOT NULL,
        leadId TEXT NOT NULL,
        employeeId INTEGER NOT NULL,
        employeeName TEXT NOT NULL,
        outcome TEXT NOT NULL,
        voiceAudioPath TEXT DEFAULT '',
        voiceTranscript TEXT DEFAULT '',
        textNotes TEXT DEFAULT '',
        submittedAt TEXT NOT NULL,
        adminComment TEXT DEFAULT '',
        suggestedLeadStatus TEXT DEFAULT '',
        FOREIGN KEY (meetingId) REFERENCES meetings(id) ON DELETE CASCADE,
        FOREIGN KEY (visitId) REFERENCES field_visits(id) ON DELETE CASCADE,
        FOREIGN KEY (leadDbId) REFERENCES leads(id) ON DELETE CASCADE,
        FOREIGN KEY (employeeId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createReportImagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS report_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reportId INTEGER NOT NULL,
        filePath TEXT NOT NULL,
        FOREIGN KEY (reportId) REFERENCES field_reports(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createGpsLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gps_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitId INTEGER NOT NULL,
        meetingId INTEGER NOT NULL,
        employeeId INTEGER NOT NULL,
        employeeName TEXT NOT NULL,
        recordedAt TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL DEFAULT 0,
        distanceFromCheckIn REAL DEFAULT 0,
        isGeofenceAlert INTEGER DEFAULT 0,
        FOREIGN KEY (visitId) REFERENCES field_visits(id) ON DELETE CASCADE,
        FOREIGN KEY (meetingId) REFERENCES meetings(id) ON DELETE CASCADE,
        FOREIGN KEY (employeeId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAlertsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        targetRole TEXT NOT NULL,
        targetUserId INTEGER,
        relatedType TEXT DEFAULT '',
        relatedId INTEGER,
        createdAt TEXT NOT NULL,
        readAt TEXT DEFAULT ''
      )
    ''');
  }

  Future<int> insertLead(Lead lead) async {
    final db = await database;
    return db.insert('leads', lead.toMap());
  }

  Future<List<Lead>> getAllLeads() async {
    final db = await database;
    final maps = await db.query('leads', orderBy: 'id DESC');
    return maps.map(Lead.fromMap).toList();
  }

  Future<Lead?> getLeadById(int id) async {
    final db = await database;
    final maps =
        await db.query('leads', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Lead.fromMap(maps.first);
  }

  Future<Lead?> getLeadByLeadId(String leadId) async {
    final db = await database;
    final maps = await db.query(
      'leads',
      where: 'leadId = ?',
      whereArgs: [leadId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Lead.fromMap(maps.first);
  }

  Future<List<Lead>> getLeadsForEmployee(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'leads',
      where: 'assignedEmployeeId = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );
    return maps.map(Lead.fromMap).toList();
  }

  Future<int> getTotalLeads() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM leads');
    return result.first['count'] as int;
  }

  Future<void> updateLeadStatus(int id, String status) async {
    final db = await database;
    await db.update('leads', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> assignLeadToEmployee({
    required int leadId,
    required int employeeId,
    required String employeeName,
  }) async {
    final db = await database;
    await db.update(
      'leads',
      {
        'assignedEmployeeId': employeeId,
        'assignedEmployeeName': employeeName,
      },
      where: 'id = ?',
      whereArgs: [leadId],
    );
  }

  Future<Lead> updateLeadWithChanges({
    required Lead lead,
    required List<LeadFieldChange> changes,
    required String changedBy,
    required String sourceTranscript,
    String sourceType = 'voice_update',
  }) async {
    if (lead.id == null) {
      throw StateError('Lead must have an id before update.');
    }
    if (changes.isEmpty) return lead;

    final db = await database;
    final values = <String, Object?>{};
    for (final change in changes) {
      values[change.fieldKey] = change.newValue;
    }
    final changedAt = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update('leads', values, where: 'id = ?', whereArgs: [lead.id]);
      for (final change in changes) {
        final history = LeadUpdateHistory(
          leadDbId: lead.id!,
          leadId: lead.leadId,
          fieldKey: change.fieldKey,
          fieldLabel: change.label,
          oldValue: change.oldValue,
          newValue: change.newValue,
          changedAt: changedAt,
          changedBy: changedBy,
          sourceType: sourceType,
          sourceTranscript: sourceTranscript,
        );
        await txn.insert('lead_update_history', history.toMap());
      }
    });

    final refreshed = await getLeadById(lead.id!);
    if (refreshed == null) {
      throw StateError('Lead update completed but lead reload failed.');
    }
    return refreshed;
  }

  Future<List<LeadUpdateHistory>> getLeadUpdateHistory(int leadDbId) async {
    final db = await database;
    final maps = await db.query(
      'lead_update_history',
      where: 'leadDbId = ?',
      whereArgs: [leadDbId],
      orderBy: 'id DESC',
    );
    return maps.map(LeadUpdateHistory.fromMap).toList();
  }

  Future<void> updateLeadSurveyLocation({
    required int id,
    required double latitude,
    required double longitude,
  }) async {
    final db = await database;
    await db.update(
      'leads',
      {'latitude': latitude, 'longitude': longitude},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSurveyStatus({
    required int id,
    required String surveyStatus,
    String? surveyStartedAt,
    String? surveyArrivedAt,
    double? surveyDistanceMeters,
    String? surveyNote,
  }) async {
    final db = await database;
    final values = <String, Object?>{'surveyStatus': surveyStatus};
    if (surveyStartedAt != null) values['surveyStartedAt'] = surveyStartedAt;
    if (surveyArrivedAt != null) values['surveyArrivedAt'] = surveyArrivedAt;
    if (surveyDistanceMeters != null)
      values['surveyDistanceMeters'] = surveyDistanceMeters;
    if (surveyNote != null) values['surveyNote'] = surveyNote;

    await db.update('leads', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Lead>> getSurveyLeads() async {
    final db = await database;
    final maps = await db.query(
      'leads',
      where: "address != '' OR location != '' OR surveyStatus != 'Not Started'",
      orderBy: 'id DESC',
    );
    return maps.map(Lead.fromMap).toList();
  }

  Future<void> deleteLead(int id) async {
    final db = await database;
    await db.delete('leads', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> generateLeadId() async {
    final count = await getTotalLeads();
    return 'LEAD-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<List<Lead>> searchLeads(String query) async {
    final db = await database;
    final maps = await db.query(
      'leads',
      where:
          'name LIKE ? OR phone LIKE ? OR location LIKE ? OR productInterest LIKE ? OR leadId LIKE ? OR assignedEmployeeName LIKE ?',
      whereArgs: [
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
      ],
      orderBy: 'id DESC',
    );
    return maps.map(Lead.fromMap).toList();
  }

  Future<Map<String, int>> getLeadTypeStats() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT leadType, COUNT(*) as count FROM leads GROUP BY leadType',
    );
    final stats = <String, int>{};
    for (final row in results) {
      stats[row['leadType'] as String] = row['count'] as int;
    }
    return stats;
  }

  Future<int> createUser(AppUser user) async {
    final db = await database;
    return db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppUser> upsertUserByIdentity(AppUser user) async {
    final existing = user.externalId.isNotEmpty
        ? await getUserByExternalId(user.externalId)
        : await getUserByUsername(user.username);
    if (existing != null) {
      final db = await database;
      final merged = AppUser(
        id: existing.id,
        externalId:
            user.externalId.isNotEmpty ? user.externalId : existing.externalId,
        companyExternalId: user.companyExternalId.isNotEmpty
            ? user.companyExternalId
            : existing.companyExternalId,
        companyName: user.companyName.isNotEmpty
            ? user.companyName
            : existing.companyName,
        companySlug: user.companySlug.isNotEmpty
            ? user.companySlug
            : existing.companySlug,
        username: user.username,
        passwordHash: user.passwordHash.isNotEmpty
            ? user.passwordHash
            : existing.passwordHash,
        role: user.role,
        fullName: user.fullName,
        isActive: user.isActive,
        createdAt:
            user.createdAt.isNotEmpty ? user.createdAt : existing.createdAt,
      );
      await db.update(
        'users',
        merged.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return merged;
    }
    final id = await createUser(user);
    return AppUser(
      id: id,
      externalId: user.externalId,
      companyExternalId: user.companyExternalId,
      companyName: user.companyName,
      companySlug: user.companySlug,
      username: user.username,
      passwordHash: user.passwordHash,
      role: user.role,
      fullName: user.fullName,
      isActive: user.isActive,
      createdAt: user.createdAt,
    );
  }

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'fullName ASC');
    return maps.map(AppUser.fromMap).toList();
  }

  Future<List<AppUser>> getEmployees() async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'role = ? AND isActive = 1',
      whereArgs: ['Employee'],
      orderBy: 'fullName ASC',
    );
    return maps.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  Future<AppUser?> getUserByExternalId(String externalId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'externalId = ?',
      whereArgs: [externalId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final maps =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  Future<void> updateUserActiveState(int userId, bool isActive) async {
    final db = await database;
    await db.update('users', {'isActive': isActive ? 1 : 0},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> createMeeting(Meeting meeting) async {
    final db = await database;
    return db.insert('meetings', meeting.toMap());
  }

  Future<List<Meeting>> getMeetings({int? employeeId}) async {
    final db = await database;
    final maps = await db.query(
      'meetings',
      where: employeeId == null ? null : 'employeeId = ?',
      whereArgs: employeeId == null ? null : [employeeId],
      orderBy: 'scheduledAt ASC',
    );
    return maps.map(Meeting.fromMap).toList();
  }

  Future<Meeting?> getMeetingById(int id) async {
    final db = await database;
    final maps =
        await db.query('meetings', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Meeting.fromMap(maps.first);
  }

  /// Tables holding tenant data. Order matters: children before parents so
  /// foreign keys never block a delete.
  static const List<String> _tenantTables = [
    'report_images',
    'gps_logs',
    'app_alerts',
    'lead_update_history',
    'field_visits',
    'field_reports',
    'meetings',
    'leads',
    'users',
  ];

  /// Wipes every cached row on this device.
  ///
  /// The local database is a cache with no company column, so when a different
  /// company's account signs in on the same device the previous tenant's rows
  /// would otherwise still be visible. The server is authoritative for anything
  /// carrying an external_id, so this only discards a cache — except meetings,
  /// which exist nowhere else and are genuinely device-local.
  Future<void> clearTenantData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in _tenantTables) {
        await txn.delete(table);
      }
    });
  }

  Future<void> updateMeetingStatus(int id, String status) async {
    final db = await database;
    await db.update('meetings', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createFieldVisit(FieldVisit visit) async {
    final db = await database;
    return db.insert('field_visits', visit.toMap());
  }

  Future<FieldVisit?> getActiveVisitForMeeting(int meetingId) async {
    final db = await database;
    final maps = await db.query(
      'field_visits',
      where: 'meetingId = ? AND status = ?',
      whereArgs: [meetingId, 'Checked In'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FieldVisit.fromMap(maps.first);
  }

  Future<List<FieldVisit>> getVisits(
      {int? employeeId, int? meetingId, bool activeOnly = false}) async {
    final db = await database;
    final where = <String>[];
    final whereArgs = <Object?>[];
    if (employeeId != null) {
      where.add('employeeId = ?');
      whereArgs.add(employeeId);
    }
    if (meetingId != null) {
      where.add('meetingId = ?');
      whereArgs.add(meetingId);
    }
    if (activeOnly) {
      where.add('status = ?');
      whereArgs.add('Checked In');
    }
    final maps = await db.query(
      'field_visits',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : whereArgs,
      orderBy: 'id DESC',
    );
    return maps.map(FieldVisit.fromMap).toList();
  }

  Future<void> updateFieldVisitCheckout({
    required int visitId,
    required String checkOutAt,
    required double checkOutLat,
    required double checkOutLng,
    required int durationMinutes,
  }) async {
    final db = await database;
    await db.update(
      'field_visits',
      {
        'checkOutAt': checkOutAt,
        'checkOutLat': checkOutLat,
        'checkOutLng': checkOutLng,
        'durationMinutes': durationMinutes,
        'status': 'Checked Out',
      },
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }

  Future<int> createFieldReport(FieldReport report) async {
    final db = await database;
    return db.insert('field_reports', report.toMap());
  }

  Future<List<FieldReport>> getReports({int? employeeId}) async {
    final db = await database;
    final maps = await db.query(
      'field_reports',
      where: employeeId == null ? null : 'employeeId = ?',
      whereArgs: employeeId == null ? null : [employeeId],
      orderBy: 'id DESC',
    );
    return maps.map(FieldReport.fromMap).toList();
  }

  Future<FieldReport?> getReportById(int id) async {
    final db = await database;
    final maps = await db.query('field_reports',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return FieldReport.fromMap(maps.first);
  }

  Future<void> updateReportAdminReview({
    required int reportId,
    required String adminComment,
    required String suggestedLeadStatus,
  }) async {
    final db = await database;
    await db.update(
      'field_reports',
      {
        'adminComment': adminComment,
        'suggestedLeadStatus': suggestedLeadStatus,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<void> addReportImages(List<ReportImage> images) async {
    final db = await database;
    final batch = db.batch();
    for (final image in images) {
      batch.insert('report_images', image.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<ReportImage>> getReportImages(int reportId) async {
    final db = await database;
    final maps = await db
        .query('report_images', where: 'reportId = ?', whereArgs: [reportId]);
    return maps.map(ReportImage.fromMap).toList();
  }

  Future<int> addGpsLog(GpsLog log) async {
    final db = await database;
    return db.insert('gps_logs', log.toMap());
  }

  Future<List<GpsLog>> getGpsLogsForVisit(int visitId) async {
    final db = await database;
    final maps = await db.query(
      'gps_logs',
      where: 'visitId = ?',
      whereArgs: [visitId],
      orderBy: 'recordedAt ASC',
    );
    return maps.map(GpsLog.fromMap).toList();
  }

  Future<GpsLog?> getLatestGpsLogForVisit(int visitId) async {
    final db = await database;
    final maps = await db.query(
      'gps_logs',
      where: 'visitId = ?',
      whereArgs: [visitId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return GpsLog.fromMap(maps.first);
  }

  Future<List<FieldVisit>> getActiveVisits() async {
    return getVisits(activeOnly: true);
  }

  Future<List<FieldVisit>> getMonitoringVisits() async {
    final db = await database;
    final maps = await db.query('field_visits', orderBy: 'id DESC');
    return maps.map(FieldVisit.fromMap).toList();
  }

  Future<void> deleteMonitoringVisit(int visitId) async {
    final db = await database;
    await db.delete('field_visits', where: 'id = ?', whereArgs: [visitId]);
  }

  Future<int> createAlert(AppAlert alert) async {
    final db = await database;
    return db.insert('app_alerts', alert.toMap());
  }

  Future<List<AppAlert>> getAlerts({required String role, int? userId}) async {
    final db = await database;
    final where = ['targetRole = ?'];
    final whereArgs = <Object?>[role];
    if (userId != null) {
      where.add('(targetUserId IS NULL OR targetUserId = ?)');
      whereArgs.add(userId);
    }
    final maps = await db.query(
      'app_alerts',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return maps.map(AppAlert.fromMap).toList();
  }

  Future<int> countUnreadAlerts({required String role, int? userId}) async {
    final db = await database;
    final where = ['targetRole = ?', "readAt = ''"];
    final whereArgs = <Object?>[role];
    if (userId != null) {
      where.add('(targetUserId IS NULL OR targetUserId = ?)');
      whereArgs.add(userId);
    }
    final result = await db.query(
      'app_alerts',
      columns: ['COUNT(*) as count'],
      where: where.join(' AND '),
      whereArgs: whereArgs,
    );
    return result.first['count'] as int;
  }

  Future<void> markAlertRead(int alertId) async {
    final db = await database;
    await db.update(
      'app_alerts',
      {'readAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }
}
