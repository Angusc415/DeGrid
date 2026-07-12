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
  /// Wall width in millimeters for this project (used when drawing completed rooms).
  RealColumn get wallWidthMm => real().withDefault(const Constant(70.0))();
  /// Optional door thickness in millimeters for this project (used when drawing doors).
  RealColumn get doorThicknessMm => real().nullable()();
  TextColumn get viewportJson => text().nullable()(); // JSON viewport state
  TextColumn get backgroundImagePath => text().nullable()(); // relative path in app storage
  TextColumn get backgroundImageJson => text().nullable()(); // JSON: offsetX, offsetY, scaleMmPerPixel, opacity
  TextColumn get openingsJson => text().nullable()(); // JSON array of Opening: roomIndex, edgeIndex, offsetMm, widthMm
  TextColumn get carpetProductsJson => text().nullable()(); // JSON array of CarpetProduct: name, rollWidthMm, rollLengthM?, costPerSqm?
  TextColumn get roomCarpetAssignmentsJson => text().nullable()(); // JSON: list of {roomIndex, productIndex}
  TextColumn get roomCarpetSeamOverridesJson => text().nullable()(); // JSON: { "roomIndex": [posMm, ...], ... }
  /// Carpet planning: waste allowance percent (user-adjustable, default 5%).
  /// Kept in sync with [carpetPlanningSettingsJson] for backwards compat.
  RealColumn get carpetWasteAllowancePercent => real().withDefault(const Constant(5.0))();
  /// Carpet planning settings as JSON (waste %, seam penalties, doorway
  /// extension, seam width allowance). Null = defaults + waste column.
  TextColumn get carpetPlanningSettingsJson => text().nullable()();
  /// Carpet planning: strip split strategy index (StripSplitStrategy.index, default 0 = auto).
  IntColumn get stripSplitStrategy => integer().withDefault(const Constant(0))();
  TextColumn get roomCarpetSeamLayDirectionDegJson => text().nullable()(); // JSON: { "roomIndex": deg, ... }
  TextColumn get roomCarpetLayoutVariantIndexJson => text().nullable()(); // JSON: { "roomIndex": variant, ... }
  TextColumn get roomCarpetStripPieceLengthsJson => text().nullable()(); // JSON: { "roomIndex": [[mm,...], ...], ... }
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
/// The [column] parameter is kept loosely typed to work across Drift versions.
Future<void> _addColumnIfNotExists(Migrator m, dynamic table, dynamic column) async {
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
  int get schemaVersion => 14;

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
        if (from < 10) {
          await _addColumnIfNotExists(m, projects, projects.roomCarpetSeamOverridesJson);
        }
        if (from < 11) {
          await _addColumnIfNotExists(m, projects, projects.wallWidthMm);
        }
        if (from < 12) {
          await _addColumnIfNotExists(m, projects, projects.doorThicknessMm);
        }
        if (from < 13) {
          await _addColumnIfNotExists(m, projects, projects.carpetWasteAllowancePercent);
          await _addColumnIfNotExists(m, projects, projects.stripSplitStrategy);
          await _addColumnIfNotExists(m, projects, projects.roomCarpetSeamLayDirectionDegJson);
          await _addColumnIfNotExists(m, projects, projects.roomCarpetLayoutVariantIndexJson);
          await _addColumnIfNotExists(m, projects, projects.roomCarpetStripPieceLengthsJson);
        }
        if (from < 14) {
          await _addColumnIfNotExists(m, projects, projects.carpetPlanningSettingsJson);
        }
      },
    );
  }
}
