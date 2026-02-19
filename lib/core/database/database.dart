import 'package:drift/drift.dart';

// Conditional imports for platform-specific database implementations
import 'database_stub.dart'
    if (dart.library.io) 'database_native.dart'
    if (dart.library.html) 'database_web.dart';

part 'database.g.dart';

/// Folders table - organizes projects into folders (file-system style)
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  IntColumn get parentId => integer().nullable().references(Folders, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

/// Projects table - stores project metadata
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  IntColumn get folderId => integer().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get useImperial => boolean().withDefault(const Constant(false))();
  TextColumn get viewportJson => text().nullable()(); // JSON viewport state
  TextColumn get backgroundImagePath => text().nullable()(); // relative path in app storage
  TextColumn get backgroundImageJson => text().nullable()(); // JSON: offsetX, offsetY, scaleMmPerPixel, opacity
  TextColumn get openingsJson => text().nullable()(); // JSON array of Opening: roomIndex, edgeIndex, offsetMm, widthMm
  TextColumn get carpetProductsJson => text().nullable()(); // JSON array of CarpetProduct: name, rollWidthMm, rollLengthM?, costPerSqm?
  TextColumn get roomCarpetAssignmentsJson => text().nullable()(); // JSON: list of {roomIndex, productIndex}
}

/// Rooms table - stores room data for each project
@DataClassName('RoomData')
class Rooms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().nullable()();
  TextColumn get verticesJson => text()(); // JSON array of {x, y} coordinates
  IntColumn get orderIndex => integer().withDefault(const Constant(0))(); // Order rooms were created
}

/// Adds a column only if it does not already exist (avoids "duplicate column name" on re-runs).
Future<void> _addColumnIfNotExists(Migrator m, dynamic table, GeneratedColumn column) async {
  try {
    await m.addColumn(table, column);
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('duplicate column name')) return;
    rethrow;
  }
}

/// Main database class
@DriftDatabase(tables: [Folders, Projects, Rooms])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await _addColumnIfNotExists(m, projects, projects.viewportJson);
        }
        if (from < 4) {
          // Remove carpet/roll planning tables (if they exist from schema 3)
          await m.database.customStatement('DROP TABLE IF EXISTS roll_plans');
          await m.database.customStatement('DROP TABLE IF EXISTS rolls');
        }
        if (from < 5) {
          await m.createTable(folders);
          await _addColumnIfNotExists(m, projects, projects.folderId);
        }
        if (from < 6) {
          await _addColumnIfNotExists(m, projects, projects.backgroundImagePath);
          await _addColumnIfNotExists(m, projects, projects.backgroundImageJson);
        }
        if (from < 7) {
          await _addColumnIfNotExists(m, projects, projects.openingsJson);
        }
        if (from < 8) {
          await _addColumnIfNotExists(m, projects, projects.carpetProductsJson);
        }
        if (from < 9) {
          await _addColumnIfNotExists(m, projects, projects.roomCarpetAssignmentsJson);
        }
      },
    );
  }
}
