// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
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
    name,
    parentId,
    createdAt,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
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
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final int orderIndex;
  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      createdAt: Value(createdAt),
      orderIndex: Value(orderIndex),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<int?>(parentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  Folder copyWith({
    int? id,
    String? name,
    Value<int?> parentId = const Value.absent(),
    DateTime? createdAt,
    int? orderIndex,
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    createdAt: createdAt ?? this.createdAt,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, createdAt, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.createdAt == this.createdAt &&
          other.orderIndex == this.orderIndex);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> parentId;
  final Value<DateTime> createdAt;
  final Value<int> orderIndex;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.orderIndex = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? parentId,
    Expression<DateTime>? createdAt,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? parentId,
    Value<DateTime>? createdAt,
    Value<int>? orderIndex,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
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
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE SET NULL',
    ),
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
  static const VerificationMeta _wallWidthMmMeta = const VerificationMeta(
    'wallWidthMm',
  );
  @override
  late final GeneratedColumn<double> wallWidthMm = GeneratedColumn<double>(
    'wall_width_mm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(70.0),
  );
  static const VerificationMeta _doorThicknessMmMeta = const VerificationMeta(
    'doorThicknessMm',
  );
  @override
  late final GeneratedColumn<double> doorThicknessMm = GeneratedColumn<double>(
    'door_thickness_mm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
  static const VerificationMeta _backgroundImagePathMeta =
      const VerificationMeta('backgroundImagePath');
  @override
  late final GeneratedColumn<String> backgroundImagePath =
      GeneratedColumn<String>(
        'background_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _backgroundImageJsonMeta =
      const VerificationMeta('backgroundImageJson');
  @override
  late final GeneratedColumn<String> backgroundImageJson =
      GeneratedColumn<String>(
        'background_image_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _openingsJsonMeta = const VerificationMeta(
    'openingsJson',
  );
  @override
  late final GeneratedColumn<String> openingsJson = GeneratedColumn<String>(
    'openings_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carpetProductsJsonMeta =
      const VerificationMeta('carpetProductsJson');
  @override
  late final GeneratedColumn<String> carpetProductsJson =
      GeneratedColumn<String>(
        'carpet_products_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _roomCarpetAssignmentsJsonMeta =
      const VerificationMeta('roomCarpetAssignmentsJson');
  @override
  late final GeneratedColumn<String> roomCarpetAssignmentsJson =
      GeneratedColumn<String>(
        'room_carpet_assignments_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _roomCarpetSeamOverridesJsonMeta =
      const VerificationMeta('roomCarpetSeamOverridesJson');
  @override
  late final GeneratedColumn<String> roomCarpetSeamOverridesJson =
      GeneratedColumn<String>(
        'room_carpet_seam_overrides_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _carpetWasteAllowancePercentMeta =
      const VerificationMeta('carpetWasteAllowancePercent');
  @override
  late final GeneratedColumn<double> carpetWasteAllowancePercent =
      GeneratedColumn<double>(
        'carpet_waste_allowance_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(5.0),
      );
  static const VerificationMeta _carpetPlanningSettingsJsonMeta =
      const VerificationMeta('carpetPlanningSettingsJson');
  @override
  late final GeneratedColumn<String> carpetPlanningSettingsJson =
      GeneratedColumn<String>(
        'carpet_planning_settings_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stripSplitStrategyMeta =
      const VerificationMeta('stripSplitStrategy');
  @override
  late final GeneratedColumn<int> stripSplitStrategy = GeneratedColumn<int>(
    'strip_split_strategy',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _roomCarpetSeamLayDirectionDegJsonMeta =
      const VerificationMeta('roomCarpetSeamLayDirectionDegJson');
  @override
  late final GeneratedColumn<String> roomCarpetSeamLayDirectionDegJson =
      GeneratedColumn<String>(
        'room_carpet_seam_lay_direction_deg_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _roomCarpetLayoutVariantIndexJsonMeta =
      const VerificationMeta('roomCarpetLayoutVariantIndexJson');
  @override
  late final GeneratedColumn<String> roomCarpetLayoutVariantIndexJson =
      GeneratedColumn<String>(
        'room_carpet_layout_variant_index_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _roomCarpetStripPieceLengthsJsonMeta =
      const VerificationMeta('roomCarpetStripPieceLengthsJson');
  @override
  late final GeneratedColumn<String> roomCarpetStripPieceLengthsJson =
      GeneratedColumn<String>(
        'room_carpet_strip_piece_lengths_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    folderId,
    createdAt,
    updatedAt,
    useImperial,
    wallWidthMm,
    doorThicknessMm,
    viewportJson,
    backgroundImagePath,
    backgroundImageJson,
    openingsJson,
    carpetProductsJson,
    roomCarpetAssignmentsJson,
    roomCarpetSeamOverridesJson,
    carpetWasteAllowancePercent,
    carpetPlanningSettingsJson,
    stripSplitStrategy,
    roomCarpetSeamLayDirectionDegJson,
    roomCarpetLayoutVariantIndexJson,
    roomCarpetStripPieceLengthsJson,
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
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
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
    if (data.containsKey('use_imperial')) {
      context.handle(
        _useImperialMeta,
        useImperial.isAcceptableOrUnknown(
          data['use_imperial']!,
          _useImperialMeta,
        ),
      );
    }
    if (data.containsKey('wall_width_mm')) {
      context.handle(
        _wallWidthMmMeta,
        wallWidthMm.isAcceptableOrUnknown(
          data['wall_width_mm']!,
          _wallWidthMmMeta,
        ),
      );
    }
    if (data.containsKey('door_thickness_mm')) {
      context.handle(
        _doorThicknessMmMeta,
        doorThicknessMm.isAcceptableOrUnknown(
          data['door_thickness_mm']!,
          _doorThicknessMmMeta,
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
    if (data.containsKey('background_image_path')) {
      context.handle(
        _backgroundImagePathMeta,
        backgroundImagePath.isAcceptableOrUnknown(
          data['background_image_path']!,
          _backgroundImagePathMeta,
        ),
      );
    }
    if (data.containsKey('background_image_json')) {
      context.handle(
        _backgroundImageJsonMeta,
        backgroundImageJson.isAcceptableOrUnknown(
          data['background_image_json']!,
          _backgroundImageJsonMeta,
        ),
      );
    }
    if (data.containsKey('openings_json')) {
      context.handle(
        _openingsJsonMeta,
        openingsJson.isAcceptableOrUnknown(
          data['openings_json']!,
          _openingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('carpet_products_json')) {
      context.handle(
        _carpetProductsJsonMeta,
        carpetProductsJson.isAcceptableOrUnknown(
          data['carpet_products_json']!,
          _carpetProductsJsonMeta,
        ),
      );
    }
    if (data.containsKey('room_carpet_assignments_json')) {
      context.handle(
        _roomCarpetAssignmentsJsonMeta,
        roomCarpetAssignmentsJson.isAcceptableOrUnknown(
          data['room_carpet_assignments_json']!,
          _roomCarpetAssignmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('room_carpet_seam_overrides_json')) {
      context.handle(
        _roomCarpetSeamOverridesJsonMeta,
        roomCarpetSeamOverridesJson.isAcceptableOrUnknown(
          data['room_carpet_seam_overrides_json']!,
          _roomCarpetSeamOverridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('carpet_waste_allowance_percent')) {
      context.handle(
        _carpetWasteAllowancePercentMeta,
        carpetWasteAllowancePercent.isAcceptableOrUnknown(
          data['carpet_waste_allowance_percent']!,
          _carpetWasteAllowancePercentMeta,
        ),
      );
    }
    if (data.containsKey('carpet_planning_settings_json')) {
      context.handle(
        _carpetPlanningSettingsJsonMeta,
        carpetPlanningSettingsJson.isAcceptableOrUnknown(
          data['carpet_planning_settings_json']!,
          _carpetPlanningSettingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('strip_split_strategy')) {
      context.handle(
        _stripSplitStrategyMeta,
        stripSplitStrategy.isAcceptableOrUnknown(
          data['strip_split_strategy']!,
          _stripSplitStrategyMeta,
        ),
      );
    }
    if (data.containsKey('room_carpet_seam_lay_direction_deg_json')) {
      context.handle(
        _roomCarpetSeamLayDirectionDegJsonMeta,
        roomCarpetSeamLayDirectionDegJson.isAcceptableOrUnknown(
          data['room_carpet_seam_lay_direction_deg_json']!,
          _roomCarpetSeamLayDirectionDegJsonMeta,
        ),
      );
    }
    if (data.containsKey('room_carpet_layout_variant_index_json')) {
      context.handle(
        _roomCarpetLayoutVariantIndexJsonMeta,
        roomCarpetLayoutVariantIndexJson.isAcceptableOrUnknown(
          data['room_carpet_layout_variant_index_json']!,
          _roomCarpetLayoutVariantIndexJsonMeta,
        ),
      );
    }
    if (data.containsKey('room_carpet_strip_piece_lengths_json')) {
      context.handle(
        _roomCarpetStripPieceLengthsJsonMeta,
        roomCarpetStripPieceLengthsJson.isAcceptableOrUnknown(
          data['room_carpet_strip_piece_lengths_json']!,
          _roomCarpetStripPieceLengthsJsonMeta,
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
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
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
      wallWidthMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wall_width_mm'],
      )!,
      doorThicknessMm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}door_thickness_mm'],
      ),
      viewportJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viewport_json'],
      ),
      backgroundImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_image_path'],
      ),
      backgroundImageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_image_json'],
      ),
      openingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}openings_json'],
      ),
      carpetProductsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carpet_products_json'],
      ),
      roomCarpetAssignmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_carpet_assignments_json'],
      ),
      roomCarpetSeamOverridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_carpet_seam_overrides_json'],
      ),
      carpetWasteAllowancePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carpet_waste_allowance_percent'],
      )!,
      carpetPlanningSettingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}carpet_planning_settings_json'],
      ),
      stripSplitStrategy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}strip_split_strategy'],
      )!,
      roomCarpetSeamLayDirectionDegJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_carpet_seam_lay_direction_deg_json'],
      ),
      roomCarpetLayoutVariantIndexJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_carpet_layout_variant_index_json'],
      ),
      roomCarpetStripPieceLengthsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_carpet_strip_piece_lengths_json'],
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
  final int? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool useImperial;

  /// Wall width in millimeters for this project (used when drawing completed rooms).
  final double wallWidthMm;

  /// Optional door thickness in millimeters for this project (used when drawing doors).
  final double? doorThicknessMm;
  final String? viewportJson;
  final String? backgroundImagePath;
  final String? backgroundImageJson;
  final String? openingsJson;
  final String? carpetProductsJson;
  final String? roomCarpetAssignmentsJson;
  final String? roomCarpetSeamOverridesJson;

  /// Carpet planning: waste allowance percent (user-adjustable, default 5%).
  /// Kept in sync with [carpetPlanningSettingsJson] for backwards compat.
  final double carpetWasteAllowancePercent;

  /// Carpet planning settings as JSON (waste %, seam penalties, doorway
  /// extension, seam width allowance). Null = defaults + waste column.
  final String? carpetPlanningSettingsJson;

  /// Carpet planning: strip split strategy index (StripSplitStrategy.index, default 0 = auto).
  final int stripSplitStrategy;
  final String? roomCarpetSeamLayDirectionDegJson;
  final String? roomCarpetLayoutVariantIndexJson;
  final String? roomCarpetStripPieceLengthsJson;
  const Project({
    required this.id,
    required this.name,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    required this.useImperial,
    required this.wallWidthMm,
    this.doorThicknessMm,
    this.viewportJson,
    this.backgroundImagePath,
    this.backgroundImageJson,
    this.openingsJson,
    this.carpetProductsJson,
    this.roomCarpetAssignmentsJson,
    this.roomCarpetSeamOverridesJson,
    required this.carpetWasteAllowancePercent,
    this.carpetPlanningSettingsJson,
    required this.stripSplitStrategy,
    this.roomCarpetSeamLayDirectionDegJson,
    this.roomCarpetLayoutVariantIndexJson,
    this.roomCarpetStripPieceLengthsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['use_imperial'] = Variable<bool>(useImperial);
    map['wall_width_mm'] = Variable<double>(wallWidthMm);
    if (!nullToAbsent || doorThicknessMm != null) {
      map['door_thickness_mm'] = Variable<double>(doorThicknessMm);
    }
    if (!nullToAbsent || viewportJson != null) {
      map['viewport_json'] = Variable<String>(viewportJson);
    }
    if (!nullToAbsent || backgroundImagePath != null) {
      map['background_image_path'] = Variable<String>(backgroundImagePath);
    }
    if (!nullToAbsent || backgroundImageJson != null) {
      map['background_image_json'] = Variable<String>(backgroundImageJson);
    }
    if (!nullToAbsent || openingsJson != null) {
      map['openings_json'] = Variable<String>(openingsJson);
    }
    if (!nullToAbsent || carpetProductsJson != null) {
      map['carpet_products_json'] = Variable<String>(carpetProductsJson);
    }
    if (!nullToAbsent || roomCarpetAssignmentsJson != null) {
      map['room_carpet_assignments_json'] = Variable<String>(
        roomCarpetAssignmentsJson,
      );
    }
    if (!nullToAbsent || roomCarpetSeamOverridesJson != null) {
      map['room_carpet_seam_overrides_json'] = Variable<String>(
        roomCarpetSeamOverridesJson,
      );
    }
    map['carpet_waste_allowance_percent'] = Variable<double>(
      carpetWasteAllowancePercent,
    );
    if (!nullToAbsent || carpetPlanningSettingsJson != null) {
      map['carpet_planning_settings_json'] = Variable<String>(
        carpetPlanningSettingsJson,
      );
    }
    map['strip_split_strategy'] = Variable<int>(stripSplitStrategy);
    if (!nullToAbsent || roomCarpetSeamLayDirectionDegJson != null) {
      map['room_carpet_seam_lay_direction_deg_json'] = Variable<String>(
        roomCarpetSeamLayDirectionDegJson,
      );
    }
    if (!nullToAbsent || roomCarpetLayoutVariantIndexJson != null) {
      map['room_carpet_layout_variant_index_json'] = Variable<String>(
        roomCarpetLayoutVariantIndexJson,
      );
    }
    if (!nullToAbsent || roomCarpetStripPieceLengthsJson != null) {
      map['room_carpet_strip_piece_lengths_json'] = Variable<String>(
        roomCarpetStripPieceLengthsJson,
      );
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      useImperial: Value(useImperial),
      wallWidthMm: Value(wallWidthMm),
      doorThicknessMm: doorThicknessMm == null && nullToAbsent
          ? const Value.absent()
          : Value(doorThicknessMm),
      viewportJson: viewportJson == null && nullToAbsent
          ? const Value.absent()
          : Value(viewportJson),
      backgroundImagePath: backgroundImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImagePath),
      backgroundImageJson: backgroundImageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImageJson),
      openingsJson: openingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(openingsJson),
      carpetProductsJson: carpetProductsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(carpetProductsJson),
      roomCarpetAssignmentsJson:
          roomCarpetAssignmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomCarpetAssignmentsJson),
      roomCarpetSeamOverridesJson:
          roomCarpetSeamOverridesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomCarpetSeamOverridesJson),
      carpetWasteAllowancePercent: Value(carpetWasteAllowancePercent),
      carpetPlanningSettingsJson:
          carpetPlanningSettingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(carpetPlanningSettingsJson),
      stripSplitStrategy: Value(stripSplitStrategy),
      roomCarpetSeamLayDirectionDegJson:
          roomCarpetSeamLayDirectionDegJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomCarpetSeamLayDirectionDegJson),
      roomCarpetLayoutVariantIndexJson:
          roomCarpetLayoutVariantIndexJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomCarpetLayoutVariantIndexJson),
      roomCarpetStripPieceLengthsJson:
          roomCarpetStripPieceLengthsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(roomCarpetStripPieceLengthsJson),
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
      folderId: serializer.fromJson<int?>(json['folderId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      useImperial: serializer.fromJson<bool>(json['useImperial']),
      wallWidthMm: serializer.fromJson<double>(json['wallWidthMm']),
      doorThicknessMm: serializer.fromJson<double?>(json['doorThicknessMm']),
      viewportJson: serializer.fromJson<String?>(json['viewportJson']),
      backgroundImagePath: serializer.fromJson<String?>(
        json['backgroundImagePath'],
      ),
      backgroundImageJson: serializer.fromJson<String?>(
        json['backgroundImageJson'],
      ),
      openingsJson: serializer.fromJson<String?>(json['openingsJson']),
      carpetProductsJson: serializer.fromJson<String?>(
        json['carpetProductsJson'],
      ),
      roomCarpetAssignmentsJson: serializer.fromJson<String?>(
        json['roomCarpetAssignmentsJson'],
      ),
      roomCarpetSeamOverridesJson: serializer.fromJson<String?>(
        json['roomCarpetSeamOverridesJson'],
      ),
      carpetWasteAllowancePercent: serializer.fromJson<double>(
        json['carpetWasteAllowancePercent'],
      ),
      carpetPlanningSettingsJson: serializer.fromJson<String?>(
        json['carpetPlanningSettingsJson'],
      ),
      stripSplitStrategy: serializer.fromJson<int>(json['stripSplitStrategy']),
      roomCarpetSeamLayDirectionDegJson: serializer.fromJson<String?>(
        json['roomCarpetSeamLayDirectionDegJson'],
      ),
      roomCarpetLayoutVariantIndexJson: serializer.fromJson<String?>(
        json['roomCarpetLayoutVariantIndexJson'],
      ),
      roomCarpetStripPieceLengthsJson: serializer.fromJson<String?>(
        json['roomCarpetStripPieceLengthsJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'folderId': serializer.toJson<int?>(folderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'useImperial': serializer.toJson<bool>(useImperial),
      'wallWidthMm': serializer.toJson<double>(wallWidthMm),
      'doorThicknessMm': serializer.toJson<double?>(doorThicknessMm),
      'viewportJson': serializer.toJson<String?>(viewportJson),
      'backgroundImagePath': serializer.toJson<String?>(backgroundImagePath),
      'backgroundImageJson': serializer.toJson<String?>(backgroundImageJson),
      'openingsJson': serializer.toJson<String?>(openingsJson),
      'carpetProductsJson': serializer.toJson<String?>(carpetProductsJson),
      'roomCarpetAssignmentsJson': serializer.toJson<String?>(
        roomCarpetAssignmentsJson,
      ),
      'roomCarpetSeamOverridesJson': serializer.toJson<String?>(
        roomCarpetSeamOverridesJson,
      ),
      'carpetWasteAllowancePercent': serializer.toJson<double>(
        carpetWasteAllowancePercent,
      ),
      'carpetPlanningSettingsJson': serializer.toJson<String?>(
        carpetPlanningSettingsJson,
      ),
      'stripSplitStrategy': serializer.toJson<int>(stripSplitStrategy),
      'roomCarpetSeamLayDirectionDegJson': serializer.toJson<String?>(
        roomCarpetSeamLayDirectionDegJson,
      ),
      'roomCarpetLayoutVariantIndexJson': serializer.toJson<String?>(
        roomCarpetLayoutVariantIndexJson,
      ),
      'roomCarpetStripPieceLengthsJson': serializer.toJson<String?>(
        roomCarpetStripPieceLengthsJson,
      ),
    };
  }

  Project copyWith({
    int? id,
    String? name,
    Value<int?> folderId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? useImperial,
    double? wallWidthMm,
    Value<double?> doorThicknessMm = const Value.absent(),
    Value<String?> viewportJson = const Value.absent(),
    Value<String?> backgroundImagePath = const Value.absent(),
    Value<String?> backgroundImageJson = const Value.absent(),
    Value<String?> openingsJson = const Value.absent(),
    Value<String?> carpetProductsJson = const Value.absent(),
    Value<String?> roomCarpetAssignmentsJson = const Value.absent(),
    Value<String?> roomCarpetSeamOverridesJson = const Value.absent(),
    double? carpetWasteAllowancePercent,
    Value<String?> carpetPlanningSettingsJson = const Value.absent(),
    int? stripSplitStrategy,
    Value<String?> roomCarpetSeamLayDirectionDegJson = const Value.absent(),
    Value<String?> roomCarpetLayoutVariantIndexJson = const Value.absent(),
    Value<String?> roomCarpetStripPieceLengthsJson = const Value.absent(),
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    folderId: folderId.present ? folderId.value : this.folderId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    useImperial: useImperial ?? this.useImperial,
    wallWidthMm: wallWidthMm ?? this.wallWidthMm,
    doorThicknessMm: doorThicknessMm.present
        ? doorThicknessMm.value
        : this.doorThicknessMm,
    viewportJson: viewportJson.present ? viewportJson.value : this.viewportJson,
    backgroundImagePath: backgroundImagePath.present
        ? backgroundImagePath.value
        : this.backgroundImagePath,
    backgroundImageJson: backgroundImageJson.present
        ? backgroundImageJson.value
        : this.backgroundImageJson,
    openingsJson: openingsJson.present ? openingsJson.value : this.openingsJson,
    carpetProductsJson: carpetProductsJson.present
        ? carpetProductsJson.value
        : this.carpetProductsJson,
    roomCarpetAssignmentsJson: roomCarpetAssignmentsJson.present
        ? roomCarpetAssignmentsJson.value
        : this.roomCarpetAssignmentsJson,
    roomCarpetSeamOverridesJson: roomCarpetSeamOverridesJson.present
        ? roomCarpetSeamOverridesJson.value
        : this.roomCarpetSeamOverridesJson,
    carpetWasteAllowancePercent:
        carpetWasteAllowancePercent ?? this.carpetWasteAllowancePercent,
    carpetPlanningSettingsJson: carpetPlanningSettingsJson.present
        ? carpetPlanningSettingsJson.value
        : this.carpetPlanningSettingsJson,
    stripSplitStrategy: stripSplitStrategy ?? this.stripSplitStrategy,
    roomCarpetSeamLayDirectionDegJson: roomCarpetSeamLayDirectionDegJson.present
        ? roomCarpetSeamLayDirectionDegJson.value
        : this.roomCarpetSeamLayDirectionDegJson,
    roomCarpetLayoutVariantIndexJson: roomCarpetLayoutVariantIndexJson.present
        ? roomCarpetLayoutVariantIndexJson.value
        : this.roomCarpetLayoutVariantIndexJson,
    roomCarpetStripPieceLengthsJson: roomCarpetStripPieceLengthsJson.present
        ? roomCarpetStripPieceLengthsJson.value
        : this.roomCarpetStripPieceLengthsJson,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      useImperial: data.useImperial.present
          ? data.useImperial.value
          : this.useImperial,
      wallWidthMm: data.wallWidthMm.present
          ? data.wallWidthMm.value
          : this.wallWidthMm,
      doorThicknessMm: data.doorThicknessMm.present
          ? data.doorThicknessMm.value
          : this.doorThicknessMm,
      viewportJson: data.viewportJson.present
          ? data.viewportJson.value
          : this.viewportJson,
      backgroundImagePath: data.backgroundImagePath.present
          ? data.backgroundImagePath.value
          : this.backgroundImagePath,
      backgroundImageJson: data.backgroundImageJson.present
          ? data.backgroundImageJson.value
          : this.backgroundImageJson,
      openingsJson: data.openingsJson.present
          ? data.openingsJson.value
          : this.openingsJson,
      carpetProductsJson: data.carpetProductsJson.present
          ? data.carpetProductsJson.value
          : this.carpetProductsJson,
      roomCarpetAssignmentsJson: data.roomCarpetAssignmentsJson.present
          ? data.roomCarpetAssignmentsJson.value
          : this.roomCarpetAssignmentsJson,
      roomCarpetSeamOverridesJson: data.roomCarpetSeamOverridesJson.present
          ? data.roomCarpetSeamOverridesJson.value
          : this.roomCarpetSeamOverridesJson,
      carpetWasteAllowancePercent: data.carpetWasteAllowancePercent.present
          ? data.carpetWasteAllowancePercent.value
          : this.carpetWasteAllowancePercent,
      carpetPlanningSettingsJson: data.carpetPlanningSettingsJson.present
          ? data.carpetPlanningSettingsJson.value
          : this.carpetPlanningSettingsJson,
      stripSplitStrategy: data.stripSplitStrategy.present
          ? data.stripSplitStrategy.value
          : this.stripSplitStrategy,
      roomCarpetSeamLayDirectionDegJson:
          data.roomCarpetSeamLayDirectionDegJson.present
          ? data.roomCarpetSeamLayDirectionDegJson.value
          : this.roomCarpetSeamLayDirectionDegJson,
      roomCarpetLayoutVariantIndexJson:
          data.roomCarpetLayoutVariantIndexJson.present
          ? data.roomCarpetLayoutVariantIndexJson.value
          : this.roomCarpetLayoutVariantIndexJson,
      roomCarpetStripPieceLengthsJson:
          data.roomCarpetStripPieceLengthsJson.present
          ? data.roomCarpetStripPieceLengthsJson.value
          : this.roomCarpetStripPieceLengthsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderId: $folderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('useImperial: $useImperial, ')
          ..write('wallWidthMm: $wallWidthMm, ')
          ..write('doorThicknessMm: $doorThicknessMm, ')
          ..write('viewportJson: $viewportJson, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('backgroundImageJson: $backgroundImageJson, ')
          ..write('openingsJson: $openingsJson, ')
          ..write('carpetProductsJson: $carpetProductsJson, ')
          ..write('roomCarpetAssignmentsJson: $roomCarpetAssignmentsJson, ')
          ..write('roomCarpetSeamOverridesJson: $roomCarpetSeamOverridesJson, ')
          ..write('carpetWasteAllowancePercent: $carpetWasteAllowancePercent, ')
          ..write('carpetPlanningSettingsJson: $carpetPlanningSettingsJson, ')
          ..write('stripSplitStrategy: $stripSplitStrategy, ')
          ..write(
            'roomCarpetSeamLayDirectionDegJson: $roomCarpetSeamLayDirectionDegJson, ',
          )
          ..write(
            'roomCarpetLayoutVariantIndexJson: $roomCarpetLayoutVariantIndexJson, ',
          )
          ..write(
            'roomCarpetStripPieceLengthsJson: $roomCarpetStripPieceLengthsJson',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    folderId,
    createdAt,
    updatedAt,
    useImperial,
    wallWidthMm,
    doorThicknessMm,
    viewportJson,
    backgroundImagePath,
    backgroundImageJson,
    openingsJson,
    carpetProductsJson,
    roomCarpetAssignmentsJson,
    roomCarpetSeamOverridesJson,
    carpetWasteAllowancePercent,
    carpetPlanningSettingsJson,
    stripSplitStrategy,
    roomCarpetSeamLayDirectionDegJson,
    roomCarpetLayoutVariantIndexJson,
    roomCarpetStripPieceLengthsJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.folderId == this.folderId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.useImperial == this.useImperial &&
          other.wallWidthMm == this.wallWidthMm &&
          other.doorThicknessMm == this.doorThicknessMm &&
          other.viewportJson == this.viewportJson &&
          other.backgroundImagePath == this.backgroundImagePath &&
          other.backgroundImageJson == this.backgroundImageJson &&
          other.openingsJson == this.openingsJson &&
          other.carpetProductsJson == this.carpetProductsJson &&
          other.roomCarpetAssignmentsJson == this.roomCarpetAssignmentsJson &&
          other.roomCarpetSeamOverridesJson ==
              this.roomCarpetSeamOverridesJson &&
          other.carpetWasteAllowancePercent ==
              this.carpetWasteAllowancePercent &&
          other.carpetPlanningSettingsJson == this.carpetPlanningSettingsJson &&
          other.stripSplitStrategy == this.stripSplitStrategy &&
          other.roomCarpetSeamLayDirectionDegJson ==
              this.roomCarpetSeamLayDirectionDegJson &&
          other.roomCarpetLayoutVariantIndexJson ==
              this.roomCarpetLayoutVariantIndexJson &&
          other.roomCarpetStripPieceLengthsJson ==
              this.roomCarpetStripPieceLengthsJson);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> folderId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> useImperial;
  final Value<double> wallWidthMm;
  final Value<double?> doorThicknessMm;
  final Value<String?> viewportJson;
  final Value<String?> backgroundImagePath;
  final Value<String?> backgroundImageJson;
  final Value<String?> openingsJson;
  final Value<String?> carpetProductsJson;
  final Value<String?> roomCarpetAssignmentsJson;
  final Value<String?> roomCarpetSeamOverridesJson;
  final Value<double> carpetWasteAllowancePercent;
  final Value<String?> carpetPlanningSettingsJson;
  final Value<int> stripSplitStrategy;
  final Value<String?> roomCarpetSeamLayDirectionDegJson;
  final Value<String?> roomCarpetLayoutVariantIndexJson;
  final Value<String?> roomCarpetStripPieceLengthsJson;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.folderId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.useImperial = const Value.absent(),
    this.wallWidthMm = const Value.absent(),
    this.doorThicknessMm = const Value.absent(),
    this.viewportJson = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    this.backgroundImageJson = const Value.absent(),
    this.openingsJson = const Value.absent(),
    this.carpetProductsJson = const Value.absent(),
    this.roomCarpetAssignmentsJson = const Value.absent(),
    this.roomCarpetSeamOverridesJson = const Value.absent(),
    this.carpetWasteAllowancePercent = const Value.absent(),
    this.carpetPlanningSettingsJson = const Value.absent(),
    this.stripSplitStrategy = const Value.absent(),
    this.roomCarpetSeamLayDirectionDegJson = const Value.absent(),
    this.roomCarpetLayoutVariantIndexJson = const Value.absent(),
    this.roomCarpetStripPieceLengthsJson = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.folderId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.useImperial = const Value.absent(),
    this.wallWidthMm = const Value.absent(),
    this.doorThicknessMm = const Value.absent(),
    this.viewportJson = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    this.backgroundImageJson = const Value.absent(),
    this.openingsJson = const Value.absent(),
    this.carpetProductsJson = const Value.absent(),
    this.roomCarpetAssignmentsJson = const Value.absent(),
    this.roomCarpetSeamOverridesJson = const Value.absent(),
    this.carpetWasteAllowancePercent = const Value.absent(),
    this.carpetPlanningSettingsJson = const Value.absent(),
    this.stripSplitStrategy = const Value.absent(),
    this.roomCarpetSeamLayDirectionDegJson = const Value.absent(),
    this.roomCarpetLayoutVariantIndexJson = const Value.absent(),
    this.roomCarpetStripPieceLengthsJson = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Project> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? folderId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? useImperial,
    Expression<double>? wallWidthMm,
    Expression<double>? doorThicknessMm,
    Expression<String>? viewportJson,
    Expression<String>? backgroundImagePath,
    Expression<String>? backgroundImageJson,
    Expression<String>? openingsJson,
    Expression<String>? carpetProductsJson,
    Expression<String>? roomCarpetAssignmentsJson,
    Expression<String>? roomCarpetSeamOverridesJson,
    Expression<double>? carpetWasteAllowancePercent,
    Expression<String>? carpetPlanningSettingsJson,
    Expression<int>? stripSplitStrategy,
    Expression<String>? roomCarpetSeamLayDirectionDegJson,
    Expression<String>? roomCarpetLayoutVariantIndexJson,
    Expression<String>? roomCarpetStripPieceLengthsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (folderId != null) 'folder_id': folderId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (useImperial != null) 'use_imperial': useImperial,
      if (wallWidthMm != null) 'wall_width_mm': wallWidthMm,
      if (doorThicknessMm != null) 'door_thickness_mm': doorThicknessMm,
      if (viewportJson != null) 'viewport_json': viewportJson,
      if (backgroundImagePath != null)
        'background_image_path': backgroundImagePath,
      if (backgroundImageJson != null)
        'background_image_json': backgroundImageJson,
      if (openingsJson != null) 'openings_json': openingsJson,
      if (carpetProductsJson != null)
        'carpet_products_json': carpetProductsJson,
      if (roomCarpetAssignmentsJson != null)
        'room_carpet_assignments_json': roomCarpetAssignmentsJson,
      if (roomCarpetSeamOverridesJson != null)
        'room_carpet_seam_overrides_json': roomCarpetSeamOverridesJson,
      if (carpetWasteAllowancePercent != null)
        'carpet_waste_allowance_percent': carpetWasteAllowancePercent,
      if (carpetPlanningSettingsJson != null)
        'carpet_planning_settings_json': carpetPlanningSettingsJson,
      if (stripSplitStrategy != null)
        'strip_split_strategy': stripSplitStrategy,
      if (roomCarpetSeamLayDirectionDegJson != null)
        'room_carpet_seam_lay_direction_deg_json':
            roomCarpetSeamLayDirectionDegJson,
      if (roomCarpetLayoutVariantIndexJson != null)
        'room_carpet_layout_variant_index_json':
            roomCarpetLayoutVariantIndexJson,
      if (roomCarpetStripPieceLengthsJson != null)
        'room_carpet_strip_piece_lengths_json': roomCarpetStripPieceLengthsJson,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? folderId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? useImperial,
    Value<double>? wallWidthMm,
    Value<double?>? doorThicknessMm,
    Value<String?>? viewportJson,
    Value<String?>? backgroundImagePath,
    Value<String?>? backgroundImageJson,
    Value<String?>? openingsJson,
    Value<String?>? carpetProductsJson,
    Value<String?>? roomCarpetAssignmentsJson,
    Value<String?>? roomCarpetSeamOverridesJson,
    Value<double>? carpetWasteAllowancePercent,
    Value<String?>? carpetPlanningSettingsJson,
    Value<int>? stripSplitStrategy,
    Value<String?>? roomCarpetSeamLayDirectionDegJson,
    Value<String?>? roomCarpetLayoutVariantIndexJson,
    Value<String?>? roomCarpetStripPieceLengthsJson,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      useImperial: useImperial ?? this.useImperial,
      wallWidthMm: wallWidthMm ?? this.wallWidthMm,
      doorThicknessMm: doorThicknessMm ?? this.doorThicknessMm,
      viewportJson: viewportJson ?? this.viewportJson,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageJson: backgroundImageJson ?? this.backgroundImageJson,
      openingsJson: openingsJson ?? this.openingsJson,
      carpetProductsJson: carpetProductsJson ?? this.carpetProductsJson,
      roomCarpetAssignmentsJson:
          roomCarpetAssignmentsJson ?? this.roomCarpetAssignmentsJson,
      roomCarpetSeamOverridesJson:
          roomCarpetSeamOverridesJson ?? this.roomCarpetSeamOverridesJson,
      carpetWasteAllowancePercent:
          carpetWasteAllowancePercent ?? this.carpetWasteAllowancePercent,
      carpetPlanningSettingsJson:
          carpetPlanningSettingsJson ?? this.carpetPlanningSettingsJson,
      stripSplitStrategy: stripSplitStrategy ?? this.stripSplitStrategy,
      roomCarpetSeamLayDirectionDegJson:
          roomCarpetSeamLayDirectionDegJson ??
          this.roomCarpetSeamLayDirectionDegJson,
      roomCarpetLayoutVariantIndexJson:
          roomCarpetLayoutVariantIndexJson ??
          this.roomCarpetLayoutVariantIndexJson,
      roomCarpetStripPieceLengthsJson:
          roomCarpetStripPieceLengthsJson ??
          this.roomCarpetStripPieceLengthsJson,
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
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
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
    if (wallWidthMm.present) {
      map['wall_width_mm'] = Variable<double>(wallWidthMm.value);
    }
    if (doorThicknessMm.present) {
      map['door_thickness_mm'] = Variable<double>(doorThicknessMm.value);
    }
    if (viewportJson.present) {
      map['viewport_json'] = Variable<String>(viewportJson.value);
    }
    if (backgroundImagePath.present) {
      map['background_image_path'] = Variable<String>(
        backgroundImagePath.value,
      );
    }
    if (backgroundImageJson.present) {
      map['background_image_json'] = Variable<String>(
        backgroundImageJson.value,
      );
    }
    if (openingsJson.present) {
      map['openings_json'] = Variable<String>(openingsJson.value);
    }
    if (carpetProductsJson.present) {
      map['carpet_products_json'] = Variable<String>(carpetProductsJson.value);
    }
    if (roomCarpetAssignmentsJson.present) {
      map['room_carpet_assignments_json'] = Variable<String>(
        roomCarpetAssignmentsJson.value,
      );
    }
    if (roomCarpetSeamOverridesJson.present) {
      map['room_carpet_seam_overrides_json'] = Variable<String>(
        roomCarpetSeamOverridesJson.value,
      );
    }
    if (carpetWasteAllowancePercent.present) {
      map['carpet_waste_allowance_percent'] = Variable<double>(
        carpetWasteAllowancePercent.value,
      );
    }
    if (carpetPlanningSettingsJson.present) {
      map['carpet_planning_settings_json'] = Variable<String>(
        carpetPlanningSettingsJson.value,
      );
    }
    if (stripSplitStrategy.present) {
      map['strip_split_strategy'] = Variable<int>(stripSplitStrategy.value);
    }
    if (roomCarpetSeamLayDirectionDegJson.present) {
      map['room_carpet_seam_lay_direction_deg_json'] = Variable<String>(
        roomCarpetSeamLayDirectionDegJson.value,
      );
    }
    if (roomCarpetLayoutVariantIndexJson.present) {
      map['room_carpet_layout_variant_index_json'] = Variable<String>(
        roomCarpetLayoutVariantIndexJson.value,
      );
    }
    if (roomCarpetStripPieceLengthsJson.present) {
      map['room_carpet_strip_piece_lengths_json'] = Variable<String>(
        roomCarpetStripPieceLengthsJson.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('folderId: $folderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('useImperial: $useImperial, ')
          ..write('wallWidthMm: $wallWidthMm, ')
          ..write('doorThicknessMm: $doorThicknessMm, ')
          ..write('viewportJson: $viewportJson, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('backgroundImageJson: $backgroundImageJson, ')
          ..write('openingsJson: $openingsJson, ')
          ..write('carpetProductsJson: $carpetProductsJson, ')
          ..write('roomCarpetAssignmentsJson: $roomCarpetAssignmentsJson, ')
          ..write('roomCarpetSeamOverridesJson: $roomCarpetSeamOverridesJson, ')
          ..write('carpetWasteAllowancePercent: $carpetWasteAllowancePercent, ')
          ..write('carpetPlanningSettingsJson: $carpetPlanningSettingsJson, ')
          ..write('stripSplitStrategy: $stripSplitStrategy, ')
          ..write(
            'roomCarpetSeamLayDirectionDegJson: $roomCarpetSeamLayDirectionDegJson, ',
          )
          ..write(
            'roomCarpetLayoutVariantIndexJson: $roomCarpetLayoutVariantIndexJson, ',
          )
          ..write(
            'roomCarpetStripPieceLengthsJson: $roomCarpetStripPieceLengthsJson',
          )
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $RoomsTable rooms = $RoomsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    projects,
    rooms,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('projects', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rooms', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> parentId,
      Value<DateTime> createdAt,
      Value<int> orderIndex,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> parentId,
      Value<DateTime> createdAt,
      Value<int> orderIndex,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _parentIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.folders.parentId, db.folders.id));

  $$FoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: $_aliasNameGenerator(db.folders.id, db.projects.folderId),
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get parentId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.folderId,
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
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get parentId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
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

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$FoldersTableAnnotationComposer get parentId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.folderId,
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
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool parentId, bool projectsRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                parentId: parentId,
                createdAt: createdAt,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> parentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                createdAt: createdAt,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({parentId = false, projectsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (projectsRefs) db.projects],
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
                    if (parentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parentId,
                                referencedTable: $$FoldersTableReferences
                                    ._parentIdTable(db),
                                referencedColumn: $$FoldersTableReferences
                                    ._parentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (projectsRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Project>(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences
                          ._projectsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FoldersTableReferences(db, table, p0).projectsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool parentId, bool projectsRefs})
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> folderId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> useImperial,
      Value<double> wallWidthMm,
      Value<double?> doorThicknessMm,
      Value<String?> viewportJson,
      Value<String?> backgroundImagePath,
      Value<String?> backgroundImageJson,
      Value<String?> openingsJson,
      Value<String?> carpetProductsJson,
      Value<String?> roomCarpetAssignmentsJson,
      Value<String?> roomCarpetSeamOverridesJson,
      Value<double> carpetWasteAllowancePercent,
      Value<String?> carpetPlanningSettingsJson,
      Value<int> stripSplitStrategy,
      Value<String?> roomCarpetSeamLayDirectionDegJson,
      Value<String?> roomCarpetLayoutVariantIndexJson,
      Value<String?> roomCarpetStripPieceLengthsJson,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> folderId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> useImperial,
      Value<double> wallWidthMm,
      Value<double?> doorThicknessMm,
      Value<String?> viewportJson,
      Value<String?> backgroundImagePath,
      Value<String?> backgroundImageJson,
      Value<String?> openingsJson,
      Value<String?> carpetProductsJson,
      Value<String?> roomCarpetAssignmentsJson,
      Value<String?> roomCarpetSeamOverridesJson,
      Value<double> carpetWasteAllowancePercent,
      Value<String?> carpetPlanningSettingsJson,
      Value<int> stripSplitStrategy,
      Value<String?> roomCarpetSeamLayDirectionDegJson,
      Value<String?> roomCarpetLayoutVariantIndexJson,
      Value<String?> roomCarpetStripPieceLengthsJson,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.projects.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

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

  ColumnFilters<double> get wallWidthMm => $composableBuilder(
    column: $table.wallWidthMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get doorThicknessMm => $composableBuilder(
    column: $table.doorThicknessMm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundImageJson => $composableBuilder(
    column: $table.backgroundImageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openingsJson => $composableBuilder(
    column: $table.openingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carpetProductsJson => $composableBuilder(
    column: $table.carpetProductsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomCarpetAssignmentsJson => $composableBuilder(
    column: $table.roomCarpetAssignmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomCarpetSeamOverridesJson => $composableBuilder(
    column: $table.roomCarpetSeamOverridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carpetWasteAllowancePercent => $composableBuilder(
    column: $table.carpetWasteAllowancePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carpetPlanningSettingsJson => $composableBuilder(
    column: $table.carpetPlanningSettingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stripSplitStrategy => $composableBuilder(
    column: $table.stripSplitStrategy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomCarpetSeamLayDirectionDegJson =>
      $composableBuilder(
        column: $table.roomCarpetSeamLayDirectionDegJson,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get roomCarpetLayoutVariantIndexJson =>
      $composableBuilder(
        column: $table.roomCarpetLayoutVariantIndexJson,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get roomCarpetStripPieceLengthsJson =>
      $composableBuilder(
        column: $table.roomCarpetStripPieceLengthsJson,
        builder: (column) => ColumnFilters(column),
      );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  ColumnOrderings<double> get wallWidthMm => $composableBuilder(
    column: $table.wallWidthMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get doorThicknessMm => $composableBuilder(
    column: $table.doorThicknessMm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundImageJson => $composableBuilder(
    column: $table.backgroundImageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingsJson => $composableBuilder(
    column: $table.openingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carpetProductsJson => $composableBuilder(
    column: $table.carpetProductsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomCarpetAssignmentsJson => $composableBuilder(
    column: $table.roomCarpetAssignmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomCarpetSeamOverridesJson => $composableBuilder(
    column: $table.roomCarpetSeamOverridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carpetWasteAllowancePercent => $composableBuilder(
    column: $table.carpetWasteAllowancePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carpetPlanningSettingsJson => $composableBuilder(
    column: $table.carpetPlanningSettingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stripSplitStrategy => $composableBuilder(
    column: $table.stripSplitStrategy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomCarpetSeamLayDirectionDegJson =>
      $composableBuilder(
        column: $table.roomCarpetSeamLayDirectionDegJson,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get roomCarpetLayoutVariantIndexJson =>
      $composableBuilder(
        column: $table.roomCarpetLayoutVariantIndexJson,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get roomCarpetStripPieceLengthsJson =>
      $composableBuilder(
        column: $table.roomCarpetStripPieceLengthsJson,
        builder: (column) => ColumnOrderings(column),
      );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<double> get wallWidthMm => $composableBuilder(
    column: $table.wallWidthMm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get doorThicknessMm => $composableBuilder(
    column: $table.doorThicknessMm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get viewportJson => $composableBuilder(
    column: $table.viewportJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundImagePath => $composableBuilder(
    column: $table.backgroundImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundImageJson => $composableBuilder(
    column: $table.backgroundImageJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openingsJson => $composableBuilder(
    column: $table.openingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carpetProductsJson => $composableBuilder(
    column: $table.carpetProductsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomCarpetAssignmentsJson => $composableBuilder(
    column: $table.roomCarpetAssignmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomCarpetSeamOverridesJson => $composableBuilder(
    column: $table.roomCarpetSeamOverridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carpetWasteAllowancePercent => $composableBuilder(
    column: $table.carpetWasteAllowancePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carpetPlanningSettingsJson => $composableBuilder(
    column: $table.carpetPlanningSettingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stripSplitStrategy => $composableBuilder(
    column: $table.stripSplitStrategy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomCarpetSeamLayDirectionDegJson =>
      $composableBuilder(
        column: $table.roomCarpetSeamLayDirectionDegJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get roomCarpetLayoutVariantIndexJson =>
      $composableBuilder(
        column: $table.roomCarpetLayoutVariantIndexJson,
        builder: (column) => column,
      );

  GeneratedColumn<String> get roomCarpetStripPieceLengthsJson =>
      $composableBuilder(
        column: $table.roomCarpetStripPieceLengthsJson,
        builder: (column) => column,
      );

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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
          PrefetchHooks Function({bool folderId, bool roomsRefs})
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
                Value<int?> folderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
                Value<double> wallWidthMm = const Value.absent(),
                Value<double?> doorThicknessMm = const Value.absent(),
                Value<String?> viewportJson = const Value.absent(),
                Value<String?> backgroundImagePath = const Value.absent(),
                Value<String?> backgroundImageJson = const Value.absent(),
                Value<String?> openingsJson = const Value.absent(),
                Value<String?> carpetProductsJson = const Value.absent(),
                Value<String?> roomCarpetAssignmentsJson = const Value.absent(),
                Value<String?> roomCarpetSeamOverridesJson =
                    const Value.absent(),
                Value<double> carpetWasteAllowancePercent =
                    const Value.absent(),
                Value<String?> carpetPlanningSettingsJson =
                    const Value.absent(),
                Value<int> stripSplitStrategy = const Value.absent(),
                Value<String?> roomCarpetSeamLayDirectionDegJson =
                    const Value.absent(),
                Value<String?> roomCarpetLayoutVariantIndexJson =
                    const Value.absent(),
                Value<String?> roomCarpetStripPieceLengthsJson =
                    const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                folderId: folderId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                useImperial: useImperial,
                wallWidthMm: wallWidthMm,
                doorThicknessMm: doorThicknessMm,
                viewportJson: viewportJson,
                backgroundImagePath: backgroundImagePath,
                backgroundImageJson: backgroundImageJson,
                openingsJson: openingsJson,
                carpetProductsJson: carpetProductsJson,
                roomCarpetAssignmentsJson: roomCarpetAssignmentsJson,
                roomCarpetSeamOverridesJson: roomCarpetSeamOverridesJson,
                carpetWasteAllowancePercent: carpetWasteAllowancePercent,
                carpetPlanningSettingsJson: carpetPlanningSettingsJson,
                stripSplitStrategy: stripSplitStrategy,
                roomCarpetSeamLayDirectionDegJson:
                    roomCarpetSeamLayDirectionDegJson,
                roomCarpetLayoutVariantIndexJson:
                    roomCarpetLayoutVariantIndexJson,
                roomCarpetStripPieceLengthsJson:
                    roomCarpetStripPieceLengthsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> folderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
                Value<double> wallWidthMm = const Value.absent(),
                Value<double?> doorThicknessMm = const Value.absent(),
                Value<String?> viewportJson = const Value.absent(),
                Value<String?> backgroundImagePath = const Value.absent(),
                Value<String?> backgroundImageJson = const Value.absent(),
                Value<String?> openingsJson = const Value.absent(),
                Value<String?> carpetProductsJson = const Value.absent(),
                Value<String?> roomCarpetAssignmentsJson = const Value.absent(),
                Value<String?> roomCarpetSeamOverridesJson =
                    const Value.absent(),
                Value<double> carpetWasteAllowancePercent =
                    const Value.absent(),
                Value<String?> carpetPlanningSettingsJson =
                    const Value.absent(),
                Value<int> stripSplitStrategy = const Value.absent(),
                Value<String?> roomCarpetSeamLayDirectionDegJson =
                    const Value.absent(),
                Value<String?> roomCarpetLayoutVariantIndexJson =
                    const Value.absent(),
                Value<String?> roomCarpetStripPieceLengthsJson =
                    const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                folderId: folderId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                useImperial: useImperial,
                wallWidthMm: wallWidthMm,
                doorThicknessMm: doorThicknessMm,
                viewportJson: viewportJson,
                backgroundImagePath: backgroundImagePath,
                backgroundImageJson: backgroundImageJson,
                openingsJson: openingsJson,
                carpetProductsJson: carpetProductsJson,
                roomCarpetAssignmentsJson: roomCarpetAssignmentsJson,
                roomCarpetSeamOverridesJson: roomCarpetSeamOverridesJson,
                carpetWasteAllowancePercent: carpetWasteAllowancePercent,
                carpetPlanningSettingsJson: carpetPlanningSettingsJson,
                stripSplitStrategy: stripSplitStrategy,
                roomCarpetSeamLayDirectionDegJson:
                    roomCarpetSeamLayDirectionDegJson,
                roomCarpetLayoutVariantIndexJson:
                    roomCarpetLayoutVariantIndexJson,
                roomCarpetStripPieceLengthsJson:
                    roomCarpetStripPieceLengthsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, roomsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (roomsRefs) db.rooms],
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
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable: $$ProjectsTableReferences
                                    ._folderIdTable(db),
                                referencedColumn: $$ProjectsTableReferences
                                    ._folderIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
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
                          $$ProjectsTableReferences(db, table, p0).roomsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.projectId == item.id),
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
      PrefetchHooks Function({bool folderId, bool roomsRefs})
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$RoomsTableTableManager get rooms =>
      $$RoomsTableTableManager(_db, _db.rooms);
}
