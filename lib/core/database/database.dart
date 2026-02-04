import 'package:drift/drift.dart';

// Conditional imports for platform-specific database implementations
import 'database_stub.dart'
    if (dart.library.io) 'database_native.dart'
    if (dart.library.html) 'database_web.dart';

part 'database.g.dart';

/// Projects table - stores project metadata
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get useImperial => boolean().withDefault(const Constant(false))();
  TextColumn get viewportJson => text().nullable()(); // JSON viewport state
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

/// Rolls table - stores carpet roll data for each project
@DataClassName('RollData')
class Rolls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get rollId => text()(); // Unique identifier for the roll
  TextColumn get name => text()(); // Display name
  RealColumn get widthMm => real()(); // Roll width in millimeters
  RealColumn get lengthMm => real()(); // Roll length in millimeters
  RealColumn get positionX => real()(); // X position in world coordinates
  RealColumn get positionY => real()(); // Y position in world coordinates
  RealColumn get rotationDegrees => real().withDefault(const Constant(0.0))(); // Rotation angle
  TextColumn get materialType => text().nullable()(); // Material type (e.g., "Berber")
  TextColumn get colorHex => text().nullable()(); // Color hex code
  RealColumn get costPerSqUnit => real().nullable()(); // Cost per square unit
  TextColumn get roomId => text().nullable()(); // Room ID this roll is assigned to
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// RollPlans table - stores roll plan metadata
@DataClassName('RollPlanData')
class RollPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get planId => text()(); // Unique identifier for the plan
  TextColumn get name => text()(); // Display name
  TextColumn get roomToRollsJson => text().nullable()(); // JSON mapping of roomId -> [rollIds]
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Main database class
@DriftDatabase(tables: [Projects, Rooms, Rolls, RollPlans])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add viewportJson column to projects table
          await m.addColumn(projects, projects.viewportJson);
        }
        if (from < 3) {
          // Add roll planning tables
          await m.createTable(rolls);
          await m.createTable(rollPlans);
        }
      },
    );
  }
}
