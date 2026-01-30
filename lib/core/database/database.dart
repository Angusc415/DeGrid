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

/// Main database class
@DriftDatabase(tables: [Projects, Rooms])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

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
      },
    );
  }
}
