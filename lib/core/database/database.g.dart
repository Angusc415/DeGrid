// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _useImperialMeta = const VerificationMeta(
    'useImperial',
  );
  @override
  late final GeneratedColumn<bool> useImperial = GeneratedColumn<bool>(
    'use_imperial',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_imperial" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _viewportJsonMeta = const VerificationMeta(
    'viewportJson',
  );
  @override
  late final GeneratedColumn<String> viewportJson = GeneratedColumn<String>(
    'viewport_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    updatedAt,
    useImperial,
    viewportJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('use_imperial')) {
      context.handle(
        _useImperialMeta,
        useImperial.isAcceptableOrUnknown(
          data['use_imperial']!,
          _useImperialMeta,
        ),
      );
    }
    if (data.containsKey('viewport_json')) {
      context.handle(
        _viewportJsonMeta,
        viewportJson.isAcceptableOrUnknown(
          data['viewport_json']!,
          _viewportJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      useImperial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_imperial'],
      )!,
      viewportJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viewport_json'],
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool useImperial;
  final String? viewportJson;
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.useImperial,
    this.viewportJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['use_imperial'] = Variable<bool>(useImperial);
    if (!nullToAbsent || viewportJson != null) {
      map['viewport_json'] = Variable<String>(viewportJson);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      useImperial: Value(useImperial),
      viewportJson: viewportJson == null && nullToAbsent
          ? const Value.absent()
          : Value(viewportJson),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      useImperial: serializer.fromJson<bool>(json['useImperial']),
      viewportJson: serializer.fromJson<String?>(json['viewportJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'useImperial': serializer.toJson<bool>(useImperial),
      'viewportJson': serializer.toJson<String?>(viewportJson),
    };
  }

  Project copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? useImperial,
    Value<String?> viewportJson = const Value.absent(),
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    useImperial: useImperial ?? this.useImperial,
    viewportJson: viewportJson.present ? viewportJson.value : this.viewportJson,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      useImperial: data.useImperial.present
          ? data.useImperial.value
          : this.useImperial,
      viewportJson: data.viewportJson.present
          ? data.viewportJson.value
          : this.viewportJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('useImperial: $useImperial, ')
          ..write('viewportJson: $viewportJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, updatedAt, useImperial, viewportJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.useImperial == this.useImperial &&
          other.viewportJson == this.viewportJson);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> useImperial;
  final Value<String?> viewportJson;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.useImperial = const Value.absent(),
    this.viewportJson = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.useImperial = const Value.absent(),
    this.viewportJson = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Project> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? useImperial,
    Expression<String>? viewportJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (useImperial != null) 'use_imperial': useImperial,
      if (viewportJson != null) 'viewport_json': viewportJson,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? useImperial,
    Value<String?>? viewportJson,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      useImperial: useImperial ?? this.useImperial,
      viewportJson: viewportJson ?? this.viewportJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (useImperial.present) {
      map['use_imperial'] = Variable<bool>(useImperial.value);
    }
    if (viewportJson.present) {
      map['viewport_json'] = Variable<String>(viewportJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('useImperial: $useImperial, ')
          ..write('viewportJson: $viewportJson')
          ..write(')'))
        .toString();
  }
}

class $RoomsTable extends Rooms with TableInfo<$RoomsTable, RoomData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verticesJsonMeta = const VerificationMeta(
    'verticesJson',
  );
  @override
  late final GeneratedColumn<String> verticesJson = GeneratedColumn<String>(
    'vertices_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    verticesJson,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoomData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('vertices_json')) {
      context.handle(
        _verticesJsonMeta,
        verticesJson.isAcceptableOrUnknown(
          data['vertices_json']!,
          _verticesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verticesJsonMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoomData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoomData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      verticesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vertices_json'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $RoomsTable createAlias(String alias) {
    return $RoomsTable(attachedDatabase, alias);
  }
}

class RoomData extends DataClass implements Insertable<RoomData> {
  final int id;
  final int projectId;
  final String? name;
  final String verticesJson;
  final int orderIndex;
  const RoomData({
    required this.id,
    required this.projectId,
    this.name,
    required this.verticesJson,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['vertices_json'] = Variable<String>(verticesJson);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  RoomsCompanion toCompanion(bool nullToAbsent) {
    return RoomsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      verticesJson: Value(verticesJson),
      orderIndex: Value(orderIndex),
    );
  }

  factory RoomData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoomData(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      name: serializer.fromJson<String?>(json['name']),
      verticesJson: serializer.fromJson<String>(json['verticesJson']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'name': serializer.toJson<String?>(name),
      'verticesJson': serializer.toJson<String>(verticesJson),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  RoomData copyWith({
    int? id,
    int? projectId,
    Value<String?> name = const Value.absent(),
    String? verticesJson,
    int? orderIndex,
  }) => RoomData(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name.present ? name.value : this.name,
    verticesJson: verticesJson ?? this.verticesJson,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  RoomData copyWithCompanion(RoomsCompanion data) {
    return RoomData(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      verticesJson: data.verticesJson.present
          ? data.verticesJson.value
          : this.verticesJson,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoomData(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('verticesJson: $verticesJson, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, name, verticesJson, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoomData &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.verticesJson == this.verticesJson &&
          other.orderIndex == this.orderIndex);
}

class RoomsCompanion extends UpdateCompanion<RoomData> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String?> name;
  final Value<String> verticesJson;
  final Value<int> orderIndex;
  const RoomsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.verticesJson = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  RoomsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.name = const Value.absent(),
    required String verticesJson,
    this.orderIndex = const Value.absent(),
  }) : projectId = Value(projectId),
       verticesJson = Value(verticesJson);
  static Insertable<RoomData> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? name,
    Expression<String>? verticesJson,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (verticesJson != null) 'vertices_json': verticesJson,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  RoomsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String?>? name,
    Value<String>? verticesJson,
    Value<int>? orderIndex,
  }) {
    return RoomsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      verticesJson: verticesJson ?? this.verticesJson,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (verticesJson.present) {
      map['vertices_json'] = Variable<String>(verticesJson.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoomsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('verticesJson: $verticesJson, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

class $RollsTable extends Rolls with TableInfo<$RollsTable, RollData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RollsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rollIdMeta = const VerificationMeta('rollId');
  @override
  late final GeneratedColumn<String> rollId = GeneratedColumn<String>(
    'roll_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMmMeta = const VerificationMeta(
    'widthMm',
  );
  @override
  late final GeneratedColumn<double> widthMm = GeneratedColumn<double>(
    'width_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMmMeta = const VerificationMeta(
    'lengthMm',
  );
  @override
  late final GeneratedColumn<double> lengthMm = GeneratedColumn<double>(
    'length_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionXMeta = const VerificationMeta(
    'positionX',
  );
  @override
  late final GeneratedColumn<double> positionX = GeneratedColumn<double>(
    'position_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionYMeta = const VerificationMeta(
    'positionY',
  );
  @override
  late final GeneratedColumn<double> positionY = GeneratedColumn<double>(
    'position_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rotationDegreesMeta = const VerificationMeta(
    'rotationDegrees',
  );
  @override
  late final GeneratedColumn<double> rotationDegrees = GeneratedColumn<double>(
    'rotation_degrees',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _materialTypeMeta = const VerificationMeta(
    'materialType',
  );
  @override
  late final GeneratedColumn<String> materialType = GeneratedColumn<String>(
    'material_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPerSqUnitMeta = const VerificationMeta(
    'costPerSqUnit',
  );
  @override
  late final GeneratedColumn<double> costPerSqUnit = GeneratedColumn<double>(
    'cost_per_sq_unit',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    rollId,
    name,
    widthMm,
    lengthMm,
    positionX,
    positionY,
    rotationDegrees,
    materialType,
    colorHex,
    costPerSqUnit,
    roomId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rolls';
  @override
  VerificationContext validateIntegrity(
    Insertable<RollData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('roll_id')) {
      context.handle(
        _rollIdMeta,
        rollId.isAcceptableOrUnknown(data['roll_id']!, _rollIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rollIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('width_mm')) {
      context.handle(
        _widthMmMeta,
        widthMm.isAcceptableOrUnknown(data['width_mm']!, _widthMmMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMmMeta);
    }
    if (data.containsKey('length_mm')) {
      context.handle(
        _lengthMmMeta,
        lengthMm.isAcceptableOrUnknown(data['length_mm']!, _lengthMmMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMmMeta);
    }
    if (data.containsKey('position_x')) {
      context.handle(
        _positionXMeta,
        positionX.isAcceptableOrUnknown(data['position_x']!, _positionXMeta),
      );
    } else if (isInserting) {
      context.missing(_positionXMeta);
    }
    if (data.containsKey('position_y')) {
      context.handle(
        _positionYMeta,
        positionY.isAcceptableOrUnknown(data['position_y']!, _positionYMeta),
      );
    } else if (isInserting) {
      context.missing(_positionYMeta);
    }
    if (data.containsKey('rotation_degrees')) {
      context.handle(
        _rotationDegreesMeta,
        rotationDegrees.isAcceptableOrUnknown(
          data['rotation_degrees']!,
          _rotationDegreesMeta,
        ),
      );
    }
    if (data.containsKey('material_type')) {
      context.handle(
        _materialTypeMeta,
        materialType.isAcceptableOrUnknown(
          data['material_type']!,
          _materialTypeMeta,
        ),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('cost_per_sq_unit')) {
      context.handle(
        _costPerSqUnitMeta,
        costPerSqUnit.isAcceptableOrUnknown(
          data['cost_per_sq_unit']!,
          _costPerSqUnitMeta,
        ),
      );
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RollData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RollData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      rollId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roll_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      widthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width_mm'],
      )!,
      lengthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length_mm'],
      )!,
      positionX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_x'],
      )!,
      positionY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_y'],
      )!,
      rotationDegrees: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation_degrees'],
      )!,
      materialType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}material_type'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      costPerSqUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_per_sq_unit'],
      ),
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RollsTable createAlias(String alias) {
    return $RollsTable(attachedDatabase, alias);
  }
}

class RollData extends DataClass implements Insertable<RollData> {
  final int id;
  final int projectId;
  final String rollId;
  final String name;
  final double widthMm;
  final double lengthMm;
  final double positionX;
  final double positionY;
  final double rotationDegrees;
  final String? materialType;
  final String? colorHex;
  final double? costPerSqUnit;
  final String? roomId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RollData({
    required this.id,
    required this.projectId,
    required this.rollId,
    required this.name,
    required this.widthMm,
    required this.lengthMm,
    required this.positionX,
    required this.positionY,
    required this.rotationDegrees,
    this.materialType,
    this.colorHex,
    this.costPerSqUnit,
    this.roomId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['roll_id'] = Variable<String>(rollId);
    map['name'] = Variable<String>(name);
    map['width_mm'] = Variable<double>(widthMm);
    map['length_mm'] = Variable<double>(lengthMm);
    map['position_x'] = Variable<double>(positionX);
    map['position_y'] = Variable<double>(positionY);
    map['rotation_degrees'] = Variable<double>(rotationDegrees);
    if (!nullToAbsent || materialType != null) {
      map['material_type'] = Variable<String>(materialType);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || costPerSqUnit != null) {
      map['cost_per_sq_unit'] = Variable<double>(costPerSqUnit);
    }
    if (!nullToAbsent || roomId != null) {
      map['room_id'] = Variable<String>(roomId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RollsCompanion toCompanion(bool nullToAbsent) {
    return RollsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      rollId: Value(rollId),
      name: Value(name),
      widthMm: Value(widthMm),
      lengthMm: Value(lengthMm),
      positionX: Value(positionX),
      positionY: Value(positionY),
      rotationDegrees: Value(rotationDegrees),
      materialType: materialType == null && nullToAbsent
          ? const Value.absent()
          : Value(materialType),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      costPerSqUnit: costPerSqUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(costPerSqUnit),
      roomId: roomId == null && nullToAbsent
          ? const Value.absent()
          : Value(roomId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RollData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RollData(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      rollId: serializer.fromJson<String>(json['rollId']),
      name: serializer.fromJson<String>(json['name']),
      widthMm: serializer.fromJson<double>(json['widthMm']),
      lengthMm: serializer.fromJson<double>(json['lengthMm']),
      positionX: serializer.fromJson<double>(json['positionX']),
      positionY: serializer.fromJson<double>(json['positionY']),
      rotationDegrees: serializer.fromJson<double>(json['rotationDegrees']),
      materialType: serializer.fromJson<String?>(json['materialType']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      costPerSqUnit: serializer.fromJson<double?>(json['costPerSqUnit']),
      roomId: serializer.fromJson<String?>(json['roomId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'rollId': serializer.toJson<String>(rollId),
      'name': serializer.toJson<String>(name),
      'widthMm': serializer.toJson<double>(widthMm),
      'lengthMm': serializer.toJson<double>(lengthMm),
      'positionX': serializer.toJson<double>(positionX),
      'positionY': serializer.toJson<double>(positionY),
      'rotationDegrees': serializer.toJson<double>(rotationDegrees),
      'materialType': serializer.toJson<String?>(materialType),
      'colorHex': serializer.toJson<String?>(colorHex),
      'costPerSqUnit': serializer.toJson<double?>(costPerSqUnit),
      'roomId': serializer.toJson<String?>(roomId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RollData copyWith({
    int? id,
    int? projectId,
    String? rollId,
    String? name,
    double? widthMm,
    double? lengthMm,
    double? positionX,
    double? positionY,
    double? rotationDegrees,
    Value<String?> materialType = const Value.absent(),
    Value<String?> colorHex = const Value.absent(),
    Value<double?> costPerSqUnit = const Value.absent(),
    Value<String?> roomId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RollData(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    rollId: rollId ?? this.rollId,
    name: name ?? this.name,
    widthMm: widthMm ?? this.widthMm,
    lengthMm: lengthMm ?? this.lengthMm,
    positionX: positionX ?? this.positionX,
    positionY: positionY ?? this.positionY,
    rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    materialType: materialType.present ? materialType.value : this.materialType,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    costPerSqUnit: costPerSqUnit.present
        ? costPerSqUnit.value
        : this.costPerSqUnit,
    roomId: roomId.present ? roomId.value : this.roomId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RollData copyWithCompanion(RollsCompanion data) {
    return RollData(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      rollId: data.rollId.present ? data.rollId.value : this.rollId,
      name: data.name.present ? data.name.value : this.name,
      widthMm: data.widthMm.present ? data.widthMm.value : this.widthMm,
      lengthMm: data.lengthMm.present ? data.lengthMm.value : this.lengthMm,
      positionX: data.positionX.present ? data.positionX.value : this.positionX,
      positionY: data.positionY.present ? data.positionY.value : this.positionY,
      rotationDegrees: data.rotationDegrees.present
          ? data.rotationDegrees.value
          : this.rotationDegrees,
      materialType: data.materialType.present
          ? data.materialType.value
          : this.materialType,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      costPerSqUnit: data.costPerSqUnit.present
          ? data.costPerSqUnit.value
          : this.costPerSqUnit,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RollData(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('rollId: $rollId, ')
          ..write('name: $name, ')
          ..write('widthMm: $widthMm, ')
          ..write('lengthMm: $lengthMm, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('rotationDegrees: $rotationDegrees, ')
          ..write('materialType: $materialType, ')
          ..write('colorHex: $colorHex, ')
          ..write('costPerSqUnit: $costPerSqUnit, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    rollId,
    name,
    widthMm,
    lengthMm,
    positionX,
    positionY,
    rotationDegrees,
    materialType,
    colorHex,
    costPerSqUnit,
    roomId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RollData &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.rollId == this.rollId &&
          other.name == this.name &&
          other.widthMm == this.widthMm &&
          other.lengthMm == this.lengthMm &&
          other.positionX == this.positionX &&
          other.positionY == this.positionY &&
          other.rotationDegrees == this.rotationDegrees &&
          other.materialType == this.materialType &&
          other.colorHex == this.colorHex &&
          other.costPerSqUnit == this.costPerSqUnit &&
          other.roomId == this.roomId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RollsCompanion extends UpdateCompanion<RollData> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> rollId;
  final Value<String> name;
  final Value<double> widthMm;
  final Value<double> lengthMm;
  final Value<double> positionX;
  final Value<double> positionY;
  final Value<double> rotationDegrees;
  final Value<String?> materialType;
  final Value<String?> colorHex;
  final Value<double?> costPerSqUnit;
  final Value<String?> roomId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RollsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.rollId = const Value.absent(),
    this.name = const Value.absent(),
    this.widthMm = const Value.absent(),
    this.lengthMm = const Value.absent(),
    this.positionX = const Value.absent(),
    this.positionY = const Value.absent(),
    this.rotationDegrees = const Value.absent(),
    this.materialType = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.costPerSqUnit = const Value.absent(),
    this.roomId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RollsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String rollId,
    required String name,
    required double widthMm,
    required double lengthMm,
    required double positionX,
    required double positionY,
    this.rotationDegrees = const Value.absent(),
    this.materialType = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.costPerSqUnit = const Value.absent(),
    this.roomId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : projectId = Value(projectId),
       rollId = Value(rollId),
       name = Value(name),
       widthMm = Value(widthMm),
       lengthMm = Value(lengthMm),
       positionX = Value(positionX),
       positionY = Value(positionY);
  static Insertable<RollData> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? rollId,
    Expression<String>? name,
    Expression<double>? widthMm,
    Expression<double>? lengthMm,
    Expression<double>? positionX,
    Expression<double>? positionY,
    Expression<double>? rotationDegrees,
    Expression<String>? materialType,
    Expression<String>? colorHex,
    Expression<double>? costPerSqUnit,
    Expression<String>? roomId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (rollId != null) 'roll_id': rollId,
      if (name != null) 'name': name,
      if (widthMm != null) 'width_mm': widthMm,
      if (lengthMm != null) 'length_mm': lengthMm,
      if (positionX != null) 'position_x': positionX,
      if (positionY != null) 'position_y': positionY,
      if (rotationDegrees != null) 'rotation_degrees': rotationDegrees,
      if (materialType != null) 'material_type': materialType,
      if (colorHex != null) 'color_hex': colorHex,
      if (costPerSqUnit != null) 'cost_per_sq_unit': costPerSqUnit,
      if (roomId != null) 'room_id': roomId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RollsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? rollId,
    Value<String>? name,
    Value<double>? widthMm,
    Value<double>? lengthMm,
    Value<double>? positionX,
    Value<double>? positionY,
    Value<double>? rotationDegrees,
    Value<String?>? materialType,
    Value<String?>? colorHex,
    Value<double?>? costPerSqUnit,
    Value<String?>? roomId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RollsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      rollId: rollId ?? this.rollId,
      name: name ?? this.name,
      widthMm: widthMm ?? this.widthMm,
      lengthMm: lengthMm ?? this.lengthMm,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      materialType: materialType ?? this.materialType,
      colorHex: colorHex ?? this.colorHex,
      costPerSqUnit: costPerSqUnit ?? this.costPerSqUnit,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (rollId.present) {
      map['roll_id'] = Variable<String>(rollId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (widthMm.present) {
      map['width_mm'] = Variable<double>(widthMm.value);
    }
    if (lengthMm.present) {
      map['length_mm'] = Variable<double>(lengthMm.value);
    }
    if (positionX.present) {
      map['position_x'] = Variable<double>(positionX.value);
    }
    if (positionY.present) {
      map['position_y'] = Variable<double>(positionY.value);
    }
    if (rotationDegrees.present) {
      map['rotation_degrees'] = Variable<double>(rotationDegrees.value);
    }
    if (materialType.present) {
      map['material_type'] = Variable<String>(materialType.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (costPerSqUnit.present) {
      map['cost_per_sq_unit'] = Variable<double>(costPerSqUnit.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RollsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('rollId: $rollId, ')
          ..write('name: $name, ')
          ..write('widthMm: $widthMm, ')
          ..write('lengthMm: $lengthMm, ')
          ..write('positionX: $positionX, ')
          ..write('positionY: $positionY, ')
          ..write('rotationDegrees: $rotationDegrees, ')
          ..write('materialType: $materialType, ')
          ..write('colorHex: $colorHex, ')
          ..write('costPerSqUnit: $costPerSqUnit, ')
          ..write('roomId: $roomId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RollPlansTable extends RollPlans
    with TableInfo<$RollPlansTable, RollPlanData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RollPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomToRollsJsonMeta = const VerificationMeta(
    'roomToRollsJson',
  );
  @override
  late final GeneratedColumn<String> roomToRollsJson = GeneratedColumn<String>(
    'room_to_rolls_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    planId,
    name,
    roomToRollsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roll_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<RollPlanData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('room_to_rolls_json')) {
      context.handle(
        _roomToRollsJsonMeta,
        roomToRollsJson.isAcceptableOrUnknown(
          data['room_to_rolls_json']!,
          _roomToRollsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RollPlanData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RollPlanData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      roomToRollsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_to_rolls_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RollPlansTable createAlias(String alias) {
    return $RollPlansTable(attachedDatabase, alias);
  }
}

class RollPlanData extends DataClass implements Insertable<RollPlanData> {
  final int id;
  final int projectId;
  final String planId;
  final String name;
  final String? roomToRollsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RollPlanData({
    required this.id,
    required this.projectId,
    required this.planId,
    required this.name,
    this.roomToRollsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['plan_id'] = Variable<String>(planId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || roomToRollsJson != null) {
      map['room_to_rolls_json'] = Variable<String>(roomToRollsJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RollPlansCompanion toCompanion(bool nullToAbsent) {
    return RollPlansCompanion(
      id: Value(id),
      projectId: Value(projectId),
      planId: Value(planId),
      name: Value(name),
      roomToRollsJson: roomToRollsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomToRollsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RollPlanData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RollPlanData(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      planId: serializer.fromJson<String>(json['planId']),
      name: serializer.fromJson<String>(json['name']),
      roomToRollsJson: serializer.fromJson<String?>(json['roomToRollsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'planId': serializer.toJson<String>(planId),
      'name': serializer.toJson<String>(name),
      'roomToRollsJson': serializer.toJson<String?>(roomToRollsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RollPlanData copyWith({
    int? id,
    int? projectId,
    String? planId,
    String? name,
    Value<String?> roomToRollsJson = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RollPlanData(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    planId: planId ?? this.planId,
    name: name ?? this.name,
    roomToRollsJson: roomToRollsJson.present
        ? roomToRollsJson.value
        : this.roomToRollsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RollPlanData copyWithCompanion(RollPlansCompanion data) {
    return RollPlanData(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      planId: data.planId.present ? data.planId.value : this.planId,
      name: data.name.present ? data.name.value : this.name,
      roomToRollsJson: data.roomToRollsJson.present
          ? data.roomToRollsJson.value
          : this.roomToRollsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RollPlanData(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('planId: $planId, ')
          ..write('name: $name, ')
          ..write('roomToRollsJson: $roomToRollsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    planId,
    name,
    roomToRollsJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RollPlanData &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.planId == this.planId &&
          other.name == this.name &&
          other.roomToRollsJson == this.roomToRollsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RollPlansCompanion extends UpdateCompanion<RollPlanData> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> planId;
  final Value<String> name;
  final Value<String?> roomToRollsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RollPlansCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.planId = const Value.absent(),
    this.name = const Value.absent(),
    this.roomToRollsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RollPlansCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String planId,
    required String name,
    this.roomToRollsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : projectId = Value(projectId),
       planId = Value(planId),
       name = Value(name);
  static Insertable<RollPlanData> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? planId,
    Expression<String>? name,
    Expression<String>? roomToRollsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (planId != null) 'plan_id': planId,
      if (name != null) 'name': name,
      if (roomToRollsJson != null) 'room_to_rolls_json': roomToRollsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RollPlansCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? planId,
    Value<String>? name,
    Value<String?>? roomToRollsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RollPlansCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      roomToRollsJson: roomToRollsJson ?? this.roomToRollsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roomToRollsJson.present) {
      map['room_to_rolls_json'] = Variable<String>(roomToRollsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RollPlansCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('planId: $planId, ')
          ..write('name: $name, ')
          ..write('roomToRollsJson: $roomToRollsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  late final $RollsTable rolls = $RollsTable(this);
  late final $RollPlansTable rollPlans = $RollPlansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    rooms,
    rolls,
    rollPlans,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rooms', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rolls', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('roll_plans', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      required String name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> useImperial,
      Value<String?> viewportJson,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> useImperial,
      Value<String?> viewportJson,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoomsTable, List<RoomData>> _roomsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rooms,
    aliasName: $_aliasNameGenerator(db.projects.id, db.rooms.projectId),
  );

  $$RoomsTableProcessedTableManager get roomsRefs {
    final manager = $$RoomsTableTableManager(
      $_db,
      $_db.rooms,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roomsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RollsTable, List<RollData>> _rollsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rolls,
    aliasName: $_aliasNameGenerator(db.projects.id, db.rolls.projectId),
  );

  $$RollsTableProcessedTableManager get rollsRefs {
    final manager = $$RollsTableTableManager(
      $_db,
      $_db.rolls,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rollsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RollPlansTable, List<RollPlanData>>
  _rollPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.rollPlans,
    aliasName: $_aliasNameGenerator(db.projects.id, db.rollPlans.projectId),
  );

  $$RollPlansTableProcessedTableManager get rollPlansRefs {
    final manager = $$RollPlansTableTableManager(
      $_db,
      $_db.rollPlans,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rollPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useImperial => $composableBuilder(
    column: $table.useImperial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> roomsRefs(
    Expression<bool> Function($$RoomsTableFilterComposer f) f,
  ) {
    final $$RoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableFilterComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rollsRefs(
    Expression<bool> Function($$RollsTableFilterComposer f) f,
  ) {
    final $$RollsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableFilterComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rollPlansRefs(
    Expression<bool> Function($$RollPlansTableFilterComposer f) f,
  ) {
    final $$RollPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rollPlans,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollPlansTableFilterComposer(
            $db: $db,
            $table: $db.rollPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useImperial => $composableBuilder(
    column: $table.useImperial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get useImperial => $composableBuilder(
    column: $table.useImperial,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => column,
  );

  Expression<T> roomsRefs<T extends Object>(
    Expression<T> Function($$RoomsTableAnnotationComposer a) f,
  ) {
    final $$RoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rooms,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.rooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rollsRefs<T extends Object>(
    Expression<T> Function($$RollsTableAnnotationComposer a) f,
  ) {
    final $$RollsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableAnnotationComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rollPlansRefs<T extends Object>(
    Expression<T> Function($$RollPlansTableAnnotationComposer a) f,
  ) {
    final $$RollPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rollPlans,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.rollPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool roomsRefs,
            bool rollsRefs,
            bool rollPlansRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
                Value<String?> viewportJson = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                useImperial: useImperial,
                viewportJson: viewportJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
                Value<String?> viewportJson = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                useImperial: useImperial,
                viewportJson: viewportJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({roomsRefs = false, rollsRefs = false, rollPlansRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (roomsRefs) db.rooms,
                    if (rollsRefs) db.rolls,
                    if (rollPlansRefs) db.rollPlans,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (roomsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          RoomData
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._roomsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).roomsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rollsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          RollData
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._rollsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).rollsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rollPlansRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          RollPlanData
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._rollPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).rollPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool roomsRefs,
        bool rollsRefs,
        bool rollPlansRefs,
      })
    >;
typedef $$RoomsTableCreateCompanionBuilder =
    RoomsCompanion Function({
      Value<int> id,
      required int projectId,
      Value<String?> name,
      required String verticesJson,
      Value<int> orderIndex,
    });
typedef $$RoomsTableUpdateCompanionBuilder =
    RoomsCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String?> name,
      Value<String> verticesJson,
      Value<int> orderIndex,
    });

final class $$RoomsTableReferences
    extends BaseReferences<_$AppDatabase, $RoomsTable, RoomData> {
  $$RoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.rooms.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoomsTableFilterComposer extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verticesJson => $composableBuilder(
    column: $table.verticesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verticesJson => $composableBuilder(
    column: $table.verticesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoomsTable> {
  $$RoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get verticesJson => $composableBuilder(
    column: $table.verticesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoomsTable,
          RoomData,
          $$RoomsTableFilterComposer,
          $$RoomsTableOrderingComposer,
          $$RoomsTableAnnotationComposer,
          $$RoomsTableCreateCompanionBuilder,
          $$RoomsTableUpdateCompanionBuilder,
          (RoomData, $$RoomsTableReferences),
          RoomData,
          PrefetchHooks Function({bool projectId})
        > {
  $$RoomsTableTableManager(_$AppDatabase db, $RoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> verticesJson = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => RoomsCompanion(
                id: id,
                projectId: projectId,
                name: name,
                verticesJson: verticesJson,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<String?> name = const Value.absent(),
                required String verticesJson,
                Value<int> orderIndex = const Value.absent(),
              }) => RoomsCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                verticesJson: verticesJson,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoomsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$RoomsTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$RoomsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoomsTable,
      RoomData,
      $$RoomsTableFilterComposer,
      $$RoomsTableOrderingComposer,
      $$RoomsTableAnnotationComposer,
      $$RoomsTableCreateCompanionBuilder,
      $$RoomsTableUpdateCompanionBuilder,
      (RoomData, $$RoomsTableReferences),
      RoomData,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$RollsTableCreateCompanionBuilder =
    RollsCompanion Function({
      Value<int> id,
      required int projectId,
      required String rollId,
      required String name,
      required double widthMm,
      required double lengthMm,
      required double positionX,
      required double positionY,
      Value<double> rotationDegrees,
      Value<String?> materialType,
      Value<String?> colorHex,
      Value<double?> costPerSqUnit,
      Value<String?> roomId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$RollsTableUpdateCompanionBuilder =
    RollsCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> rollId,
      Value<String> name,
      Value<double> widthMm,
      Value<double> lengthMm,
      Value<double> positionX,
      Value<double> positionY,
      Value<double> rotationDegrees,
      Value<String?> materialType,
      Value<String?> colorHex,
      Value<double?> costPerSqUnit,
      Value<String?> roomId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$RollsTableReferences
    extends BaseReferences<_$AppDatabase, $RollsTable, RollData> {
  $$RollsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.rolls.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RollsTableFilterComposer extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rollId => $composableBuilder(
    column: $table.rollId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lengthMm => $composableBuilder(
    column: $table.lengthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionX => $composableBuilder(
    column: $table.positionX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionY => $composableBuilder(
    column: $table.positionY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotationDegrees => $composableBuilder(
    column: $table.rotationDegrees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get materialType => $composableBuilder(
    column: $table.materialType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPerSqUnit => $composableBuilder(
    column: $table.costPerSqUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollsTableOrderingComposer
    extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rollId => $composableBuilder(
    column: $table.rollId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get widthMm => $composableBuilder(
    column: $table.widthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lengthMm => $composableBuilder(
    column: $table.lengthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionX => $composableBuilder(
    column: $table.positionX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionY => $composableBuilder(
    column: $table.positionY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotationDegrees => $composableBuilder(
    column: $table.rotationDegrees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get materialType => $composableBuilder(
    column: $table.materialType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPerSqUnit => $composableBuilder(
    column: $table.costPerSqUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rollId =>
      $composableBuilder(column: $table.rollId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get widthMm =>
      $composableBuilder(column: $table.widthMm, builder: (column) => column);

  GeneratedColumn<double> get lengthMm =>
      $composableBuilder(column: $table.lengthMm, builder: (column) => column);

  GeneratedColumn<double> get positionX =>
      $composableBuilder(column: $table.positionX, builder: (column) => column);

  GeneratedColumn<double> get positionY =>
      $composableBuilder(column: $table.positionY, builder: (column) => column);

  GeneratedColumn<double> get rotationDegrees => $composableBuilder(
    column: $table.rotationDegrees,
    builder: (column) => column,
  );

  GeneratedColumn<String> get materialType => $composableBuilder(
    column: $table.materialType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<double> get costPerSqUnit => $composableBuilder(
    column: $table.costPerSqUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RollsTable,
          RollData,
          $$RollsTableFilterComposer,
          $$RollsTableOrderingComposer,
          $$RollsTableAnnotationComposer,
          $$RollsTableCreateCompanionBuilder,
          $$RollsTableUpdateCompanionBuilder,
          (RollData, $$RollsTableReferences),
          RollData,
          PrefetchHooks Function({bool projectId})
        > {
  $$RollsTableTableManager(_$AppDatabase db, $RollsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RollsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RollsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RollsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> rollId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> widthMm = const Value.absent(),
                Value<double> lengthMm = const Value.absent(),
                Value<double> positionX = const Value.absent(),
                Value<double> positionY = const Value.absent(),
                Value<double> rotationDegrees = const Value.absent(),
                Value<String?> materialType = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<double?> costPerSqUnit = const Value.absent(),
                Value<String?> roomId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RollsCompanion(
                id: id,
                projectId: projectId,
                rollId: rollId,
                name: name,
                widthMm: widthMm,
                lengthMm: lengthMm,
                positionX: positionX,
                positionY: positionY,
                rotationDegrees: rotationDegrees,
                materialType: materialType,
                colorHex: colorHex,
                costPerSqUnit: costPerSqUnit,
                roomId: roomId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String rollId,
                required String name,
                required double widthMm,
                required double lengthMm,
                required double positionX,
                required double positionY,
                Value<double> rotationDegrees = const Value.absent(),
                Value<String?> materialType = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<double?> costPerSqUnit = const Value.absent(),
                Value<String?> roomId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RollsCompanion.insert(
                id: id,
                projectId: projectId,
                rollId: rollId,
                name: name,
                widthMm: widthMm,
                lengthMm: lengthMm,
                positionX: positionX,
                positionY: positionY,
                rotationDegrees: rotationDegrees,
                materialType: materialType,
                colorHex: colorHex,
                costPerSqUnit: costPerSqUnit,
                roomId: roomId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RollsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$RollsTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$RollsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RollsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RollsTable,
      RollData,
      $$RollsTableFilterComposer,
      $$RollsTableOrderingComposer,
      $$RollsTableAnnotationComposer,
      $$RollsTableCreateCompanionBuilder,
      $$RollsTableUpdateCompanionBuilder,
      (RollData, $$RollsTableReferences),
      RollData,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$RollPlansTableCreateCompanionBuilder =
    RollPlansCompanion Function({
      Value<int> id,
      required int projectId,
      required String planId,
      required String name,
      Value<String?> roomToRollsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$RollPlansTableUpdateCompanionBuilder =
    RollPlansCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> planId,
      Value<String> name,
      Value<String?> roomToRollsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$RollPlansTableReferences
    extends BaseReferences<_$AppDatabase, $RollPlansTable, RollPlanData> {
  $$RollPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.rollPlans.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RollPlansTableFilterComposer
    extends Composer<_$AppDatabase, $RollPlansTable> {
  $$RollPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomToRollsJson => $composableBuilder(
    column: $table.roomToRollsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $RollPlansTable> {
  $$RollPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomToRollsJson => $composableBuilder(
    column: $table.roomToRollsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $RollPlansTable> {
  $$RollPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get roomToRollsJson => $composableBuilder(
    column: $table.roomToRollsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RollPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RollPlansTable,
          RollPlanData,
          $$RollPlansTableFilterComposer,
          $$RollPlansTableOrderingComposer,
          $$RollPlansTableAnnotationComposer,
          $$RollPlansTableCreateCompanionBuilder,
          $$RollPlansTableUpdateCompanionBuilder,
          (RollPlanData, $$RollPlansTableReferences),
          RollPlanData,
          PrefetchHooks Function({bool projectId})
        > {
  $$RollPlansTableTableManager(_$AppDatabase db, $RollPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RollPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RollPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RollPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> roomToRollsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RollPlansCompanion(
                id: id,
                projectId: projectId,
                planId: planId,
                name: name,
                roomToRollsJson: roomToRollsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String planId,
                required String name,
                Value<String?> roomToRollsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RollPlansCompanion.insert(
                id: id,
                projectId: projectId,
                planId: planId,
                name: name,
                roomToRollsJson: roomToRollsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RollPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$RollPlansTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$RollPlansTableReferences
                                    ._projectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RollPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RollPlansTable,
      RollPlanData,
      $$RollPlansTableFilterComposer,
      $$RollPlansTableOrderingComposer,
      $$RollPlansTableAnnotationComposer,
      $$RollPlansTableCreateCompanionBuilder,
      $$RollPlansTableUpdateCompanionBuilder,
      (RollPlanData, $$RollPlansTableReferences),
      RollPlanData,
      PrefetchHooks Function({bool projectId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
  $$RollsTableTableManager get rolls =>
      $$RollsTableTableManager(_db, _db.rolls);
  $$RollPlansTableTableManager get rollPlans =>
      $$RollPlansTableTableManager(_db, _db.rollPlans);
}
