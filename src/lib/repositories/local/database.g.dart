// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RepertoiresTable extends Repertoires
    with TableInfo<$RepertoiresTable, Repertoire> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepertoiresTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repertoires';
  @override
  VerificationContext validateIntegrity(
    Insertable<Repertoire> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Repertoire map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Repertoire(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $RepertoiresTable createAlias(String alias) {
    return $RepertoiresTable(attachedDatabase, alias);
  }
}

class Repertoire extends DataClass implements Insertable<Repertoire> {
  final int id;
  final String name;
  const Repertoire({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  RepertoiresCompanion toCompanion(bool nullToAbsent) {
    return RepertoiresCompanion(id: Value(id), name: Value(name));
  }

  factory Repertoire.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Repertoire(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Repertoire copyWith({int? id, String? name}) =>
      Repertoire(id: id ?? this.id, name: name ?? this.name);
  Repertoire copyWithCompanion(RepertoiresCompanion data) {
    return Repertoire(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Repertoire(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Repertoire && other.id == this.id && other.name == this.name);
}

class RepertoiresCompanion extends UpdateCompanion<Repertoire> {
  final Value<int> id;
  final Value<String> name;
  const RepertoiresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  RepertoiresCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Repertoire> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  RepertoiresCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return RepertoiresCompanion(id: id ?? this.id, name: name ?? this.name);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepertoiresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $RepertoireMovesTable extends RepertoireMoves
    with TableInfo<$RepertoireMovesTable, RepertoireMove> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepertoireMovesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta(
    'repertoireId',
  );
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repertoires (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _parentMoveIdMeta = const VerificationMeta(
    'parentMoveId',
  );
  @override
  late final GeneratedColumn<int> parentMoveId = GeneratedColumn<int>(
    'parent_move_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repertoire_moves (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fenMeta = const VerificationMeta('fen');
  @override
  late final GeneratedColumn<String> fen = GeneratedColumn<String>(
    'fen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sanMeta = const VerificationMeta('san');
  @override
  late final GeneratedColumn<String> san = GeneratedColumn<String>(
    'san',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repertoireId,
    parentMoveId,
    fen,
    san,
    label,
    comment,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repertoire_moves';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepertoireMove> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('repertoire_id')) {
      context.handle(
        _repertoireIdMeta,
        repertoireId.isAcceptableOrUnknown(
          data['repertoire_id']!,
          _repertoireIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('parent_move_id')) {
      context.handle(
        _parentMoveIdMeta,
        parentMoveId.isAcceptableOrUnknown(
          data['parent_move_id']!,
          _parentMoveIdMeta,
        ),
      );
    }
    if (data.containsKey('fen')) {
      context.handle(
        _fenMeta,
        fen.isAcceptableOrUnknown(data['fen']!, _fenMeta),
      );
    } else if (isInserting) {
      context.missing(_fenMeta);
    }
    if (data.containsKey('san')) {
      context.handle(
        _sanMeta,
        san.isAcceptableOrUnknown(data['san']!, _sanMeta),
      );
    } else if (isInserting) {
      context.missing(_sanMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepertoireMove map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepertoireMove(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repertoireId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repertoire_id'],
      )!,
      parentMoveId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_move_id'],
      ),
      fen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fen'],
      )!,
      san: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}san'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $RepertoireMovesTable createAlias(String alias) {
    return $RepertoireMovesTable(attachedDatabase, alias);
  }
}

class RepertoireMove extends DataClass implements Insertable<RepertoireMove> {
  final int id;
  final int repertoireId;
  final int? parentMoveId;
  final String fen;
  final String san;
  final String? label;
  final String? comment;
  final int sortOrder;
  const RepertoireMove({
    required this.id,
    required this.repertoireId,
    this.parentMoveId,
    required this.fen,
    required this.san,
    this.label,
    this.comment,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repertoire_id'] = Variable<int>(repertoireId);
    if (!nullToAbsent || parentMoveId != null) {
      map['parent_move_id'] = Variable<int>(parentMoveId);
    }
    map['fen'] = Variable<String>(fen);
    map['san'] = Variable<String>(san);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RepertoireMovesCompanion toCompanion(bool nullToAbsent) {
    return RepertoireMovesCompanion(
      id: Value(id),
      repertoireId: Value(repertoireId),
      parentMoveId: parentMoveId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentMoveId),
      fen: Value(fen),
      san: Value(san),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      sortOrder: Value(sortOrder),
    );
  }

  factory RepertoireMove.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepertoireMove(
      id: serializer.fromJson<int>(json['id']),
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      parentMoveId: serializer.fromJson<int?>(json['parentMoveId']),
      fen: serializer.fromJson<String>(json['fen']),
      san: serializer.fromJson<String>(json['san']),
      label: serializer.fromJson<String?>(json['label']),
      comment: serializer.fromJson<String?>(json['comment']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repertoireId': serializer.toJson<int>(repertoireId),
      'parentMoveId': serializer.toJson<int?>(parentMoveId),
      'fen': serializer.toJson<String>(fen),
      'san': serializer.toJson<String>(san),
      'label': serializer.toJson<String?>(label),
      'comment': serializer.toJson<String?>(comment),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  RepertoireMove copyWith({
    int? id,
    int? repertoireId,
    Value<int?> parentMoveId = const Value.absent(),
    String? fen,
    String? san,
    Value<String?> label = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    int? sortOrder,
  }) => RepertoireMove(
    id: id ?? this.id,
    repertoireId: repertoireId ?? this.repertoireId,
    parentMoveId: parentMoveId.present ? parentMoveId.value : this.parentMoveId,
    fen: fen ?? this.fen,
    san: san ?? this.san,
    label: label.present ? label.value : this.label,
    comment: comment.present ? comment.value : this.comment,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  RepertoireMove copyWithCompanion(RepertoireMovesCompanion data) {
    return RepertoireMove(
      id: data.id.present ? data.id.value : this.id,
      repertoireId: data.repertoireId.present
          ? data.repertoireId.value
          : this.repertoireId,
      parentMoveId: data.parentMoveId.present
          ? data.parentMoveId.value
          : this.parentMoveId,
      fen: data.fen.present ? data.fen.value : this.fen,
      san: data.san.present ? data.san.value : this.san,
      label: data.label.present ? data.label.value : this.label,
      comment: data.comment.present ? data.comment.value : this.comment,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepertoireMove(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('parentMoveId: $parentMoveId, ')
          ..write('fen: $fen, ')
          ..write('san: $san, ')
          ..write('label: $label, ')
          ..write('comment: $comment, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repertoireId,
    parentMoveId,
    fen,
    san,
    label,
    comment,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepertoireMove &&
          other.id == this.id &&
          other.repertoireId == this.repertoireId &&
          other.parentMoveId == this.parentMoveId &&
          other.fen == this.fen &&
          other.san == this.san &&
          other.label == this.label &&
          other.comment == this.comment &&
          other.sortOrder == this.sortOrder);
}

class RepertoireMovesCompanion extends UpdateCompanion<RepertoireMove> {
  final Value<int> id;
  final Value<int> repertoireId;
  final Value<int?> parentMoveId;
  final Value<String> fen;
  final Value<String> san;
  final Value<String?> label;
  final Value<String?> comment;
  final Value<int> sortOrder;
  const RepertoireMovesCompanion({
    this.id = const Value.absent(),
    this.repertoireId = const Value.absent(),
    this.parentMoveId = const Value.absent(),
    this.fen = const Value.absent(),
    this.san = const Value.absent(),
    this.label = const Value.absent(),
    this.comment = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  RepertoireMovesCompanion.insert({
    this.id = const Value.absent(),
    required int repertoireId,
    this.parentMoveId = const Value.absent(),
    required String fen,
    required String san,
    this.label = const Value.absent(),
    this.comment = const Value.absent(),
    required int sortOrder,
  }) : repertoireId = Value(repertoireId),
       fen = Value(fen),
       san = Value(san),
       sortOrder = Value(sortOrder);
  static Insertable<RepertoireMove> custom({
    Expression<int>? id,
    Expression<int>? repertoireId,
    Expression<int>? parentMoveId,
    Expression<String>? fen,
    Expression<String>? san,
    Expression<String>? label,
    Expression<String>? comment,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (parentMoveId != null) 'parent_move_id': parentMoveId,
      if (fen != null) 'fen': fen,
      if (san != null) 'san': san,
      if (label != null) 'label': label,
      if (comment != null) 'comment': comment,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  RepertoireMovesCompanion copyWith({
    Value<int>? id,
    Value<int>? repertoireId,
    Value<int?>? parentMoveId,
    Value<String>? fen,
    Value<String>? san,
    Value<String?>? label,
    Value<String?>? comment,
    Value<int>? sortOrder,
  }) {
    return RepertoireMovesCompanion(
      id: id ?? this.id,
      repertoireId: repertoireId ?? this.repertoireId,
      parentMoveId: parentMoveId ?? this.parentMoveId,
      fen: fen ?? this.fen,
      san: san ?? this.san,
      label: label ?? this.label,
      comment: comment ?? this.comment,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (parentMoveId.present) {
      map['parent_move_id'] = Variable<int>(parentMoveId.value);
    }
    if (fen.present) {
      map['fen'] = Variable<String>(fen.value);
    }
    if (san.present) {
      map['san'] = Variable<String>(san.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepertoireMovesCompanion(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('parentMoveId: $parentMoveId, ')
          ..write('fen: $fen, ')
          ..write('san: $san, ')
          ..write('label: $label, ')
          ..write('comment: $comment, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ReviewCardsTable extends ReviewCards
    with TableInfo<$ReviewCardsTable, ReviewCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repertoireIdMeta = const VerificationMeta(
    'repertoireId',
  );
  @override
  late final GeneratedColumn<int> repertoireId = GeneratedColumn<int>(
    'repertoire_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repertoires (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _leafMoveIdMeta = const VerificationMeta(
    'leafMoveId',
  );
  @override
  late final GeneratedColumn<int> leafMoveId = GeneratedColumn<int>(
    'leaf_move_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repertoire_moves (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _easeFactorMeta = const VerificationMeta(
    'easeFactor',
  );
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
    'ease_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextReviewDateMeta = const VerificationMeta(
    'nextReviewDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextReviewDate =
      GeneratedColumn<DateTime>(
        'next_review_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastQualityMeta = const VerificationMeta(
    'lastQuality',
  );
  @override
  late final GeneratedColumn<int> lastQuality = GeneratedColumn<int>(
    'last_quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastExtraPracticeDateMeta =
      const VerificationMeta('lastExtraPracticeDate');
  @override
  late final GeneratedColumn<DateTime> lastExtraPracticeDate =
      GeneratedColumn<DateTime>(
        'last_extra_practice_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repertoireId,
    leafMoveId,
    easeFactor,
    intervalDays,
    repetitions,
    nextReviewDate,
    lastQuality,
    lastExtraPracticeDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('repertoire_id')) {
      context.handle(
        _repertoireIdMeta,
        repertoireId.isAcceptableOrUnknown(
          data['repertoire_id']!,
          _repertoireIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repertoireIdMeta);
    }
    if (data.containsKey('leaf_move_id')) {
      context.handle(
        _leafMoveIdMeta,
        leafMoveId.isAcceptableOrUnknown(
          data['leaf_move_id']!,
          _leafMoveIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leafMoveIdMeta);
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
        _easeFactorMeta,
        easeFactor.isAcceptableOrUnknown(data['ease_factor']!, _easeFactorMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('next_review_date')) {
      context.handle(
        _nextReviewDateMeta,
        nextReviewDate.isAcceptableOrUnknown(
          data['next_review_date']!,
          _nextReviewDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextReviewDateMeta);
    }
    if (data.containsKey('last_quality')) {
      context.handle(
        _lastQualityMeta,
        lastQuality.isAcceptableOrUnknown(
          data['last_quality']!,
          _lastQualityMeta,
        ),
      );
    }
    if (data.containsKey('last_extra_practice_date')) {
      context.handle(
        _lastExtraPracticeDateMeta,
        lastExtraPracticeDate.isAcceptableOrUnknown(
          data['last_extra_practice_date']!,
          _lastExtraPracticeDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repertoireId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repertoire_id'],
      )!,
      leafMoveId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}leaf_move_id'],
      )!,
      easeFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease_factor'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      nextReviewDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_date'],
      )!,
      lastQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_quality'],
      ),
      lastExtraPracticeDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_extra_practice_date'],
      ),
    );
  }

  @override
  $ReviewCardsTable createAlias(String alias) {
    return $ReviewCardsTable(attachedDatabase, alias);
  }
}

class ReviewCard extends DataClass implements Insertable<ReviewCard> {
  final int id;
  final int repertoireId;
  final int leafMoveId;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReviewDate;
  final int? lastQuality;
  final DateTime? lastExtraPracticeDate;
  const ReviewCard({
    required this.id,
    required this.repertoireId,
    required this.leafMoveId,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewDate,
    this.lastQuality,
    this.lastExtraPracticeDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['repertoire_id'] = Variable<int>(repertoireId);
    map['leaf_move_id'] = Variable<int>(leafMoveId);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['interval_days'] = Variable<int>(intervalDays);
    map['repetitions'] = Variable<int>(repetitions);
    map['next_review_date'] = Variable<DateTime>(nextReviewDate);
    if (!nullToAbsent || lastQuality != null) {
      map['last_quality'] = Variable<int>(lastQuality);
    }
    if (!nullToAbsent || lastExtraPracticeDate != null) {
      map['last_extra_practice_date'] = Variable<DateTime>(
        lastExtraPracticeDate,
      );
    }
    return map;
  }

  ReviewCardsCompanion toCompanion(bool nullToAbsent) {
    return ReviewCardsCompanion(
      id: Value(id),
      repertoireId: Value(repertoireId),
      leafMoveId: Value(leafMoveId),
      easeFactor: Value(easeFactor),
      intervalDays: Value(intervalDays),
      repetitions: Value(repetitions),
      nextReviewDate: Value(nextReviewDate),
      lastQuality: lastQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(lastQuality),
      lastExtraPracticeDate: lastExtraPracticeDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastExtraPracticeDate),
    );
  }

  factory ReviewCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewCard(
      id: serializer.fromJson<int>(json['id']),
      repertoireId: serializer.fromJson<int>(json['repertoireId']),
      leafMoveId: serializer.fromJson<int>(json['leafMoveId']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      nextReviewDate: serializer.fromJson<DateTime>(json['nextReviewDate']),
      lastQuality: serializer.fromJson<int?>(json['lastQuality']),
      lastExtraPracticeDate: serializer.fromJson<DateTime?>(
        json['lastExtraPracticeDate'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repertoireId': serializer.toJson<int>(repertoireId),
      'leafMoveId': serializer.toJson<int>(leafMoveId),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'repetitions': serializer.toJson<int>(repetitions),
      'nextReviewDate': serializer.toJson<DateTime>(nextReviewDate),
      'lastQuality': serializer.toJson<int?>(lastQuality),
      'lastExtraPracticeDate': serializer.toJson<DateTime?>(
        lastExtraPracticeDate,
      ),
    };
  }

  ReviewCard copyWith({
    int? id,
    int? repertoireId,
    int? leafMoveId,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReviewDate,
    Value<int?> lastQuality = const Value.absent(),
    Value<DateTime?> lastExtraPracticeDate = const Value.absent(),
  }) => ReviewCard(
    id: id ?? this.id,
    repertoireId: repertoireId ?? this.repertoireId,
    leafMoveId: leafMoveId ?? this.leafMoveId,
    easeFactor: easeFactor ?? this.easeFactor,
    intervalDays: intervalDays ?? this.intervalDays,
    repetitions: repetitions ?? this.repetitions,
    nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    lastQuality: lastQuality.present ? lastQuality.value : this.lastQuality,
    lastExtraPracticeDate: lastExtraPracticeDate.present
        ? lastExtraPracticeDate.value
        : this.lastExtraPracticeDate,
  );
  ReviewCard copyWithCompanion(ReviewCardsCompanion data) {
    return ReviewCard(
      id: data.id.present ? data.id.value : this.id,
      repertoireId: data.repertoireId.present
          ? data.repertoireId.value
          : this.repertoireId,
      leafMoveId: data.leafMoveId.present
          ? data.leafMoveId.value
          : this.leafMoveId,
      easeFactor: data.easeFactor.present
          ? data.easeFactor.value
          : this.easeFactor,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      nextReviewDate: data.nextReviewDate.present
          ? data.nextReviewDate.value
          : this.nextReviewDate,
      lastQuality: data.lastQuality.present
          ? data.lastQuality.value
          : this.lastQuality,
      lastExtraPracticeDate: data.lastExtraPracticeDate.present
          ? data.lastExtraPracticeDate.value
          : this.lastExtraPracticeDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewCard(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('leafMoveId: $leafMoveId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('nextReviewDate: $nextReviewDate, ')
          ..write('lastQuality: $lastQuality, ')
          ..write('lastExtraPracticeDate: $lastExtraPracticeDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repertoireId,
    leafMoveId,
    easeFactor,
    intervalDays,
    repetitions,
    nextReviewDate,
    lastQuality,
    lastExtraPracticeDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewCard &&
          other.id == this.id &&
          other.repertoireId == this.repertoireId &&
          other.leafMoveId == this.leafMoveId &&
          other.easeFactor == this.easeFactor &&
          other.intervalDays == this.intervalDays &&
          other.repetitions == this.repetitions &&
          other.nextReviewDate == this.nextReviewDate &&
          other.lastQuality == this.lastQuality &&
          other.lastExtraPracticeDate == this.lastExtraPracticeDate);
}

class ReviewCardsCompanion extends UpdateCompanion<ReviewCard> {
  final Value<int> id;
  final Value<int> repertoireId;
  final Value<int> leafMoveId;
  final Value<double> easeFactor;
  final Value<int> intervalDays;
  final Value<int> repetitions;
  final Value<DateTime> nextReviewDate;
  final Value<int?> lastQuality;
  final Value<DateTime?> lastExtraPracticeDate;
  const ReviewCardsCompanion({
    this.id = const Value.absent(),
    this.repertoireId = const Value.absent(),
    this.leafMoveId = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.nextReviewDate = const Value.absent(),
    this.lastQuality = const Value.absent(),
    this.lastExtraPracticeDate = const Value.absent(),
  });
  ReviewCardsCompanion.insert({
    this.id = const Value.absent(),
    required int repertoireId,
    required int leafMoveId,
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    required DateTime nextReviewDate,
    this.lastQuality = const Value.absent(),
    this.lastExtraPracticeDate = const Value.absent(),
  }) : repertoireId = Value(repertoireId),
       leafMoveId = Value(leafMoveId),
       nextReviewDate = Value(nextReviewDate);
  static Insertable<ReviewCard> custom({
    Expression<int>? id,
    Expression<int>? repertoireId,
    Expression<int>? leafMoveId,
    Expression<double>? easeFactor,
    Expression<int>? intervalDays,
    Expression<int>? repetitions,
    Expression<DateTime>? nextReviewDate,
    Expression<int>? lastQuality,
    Expression<DateTime>? lastExtraPracticeDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repertoireId != null) 'repertoire_id': repertoireId,
      if (leafMoveId != null) 'leaf_move_id': leafMoveId,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (repetitions != null) 'repetitions': repetitions,
      if (nextReviewDate != null) 'next_review_date': nextReviewDate,
      if (lastQuality != null) 'last_quality': lastQuality,
      if (lastExtraPracticeDate != null)
        'last_extra_practice_date': lastExtraPracticeDate,
    });
  }

  ReviewCardsCompanion copyWith({
    Value<int>? id,
    Value<int>? repertoireId,
    Value<int>? leafMoveId,
    Value<double>? easeFactor,
    Value<int>? intervalDays,
    Value<int>? repetitions,
    Value<DateTime>? nextReviewDate,
    Value<int?>? lastQuality,
    Value<DateTime?>? lastExtraPracticeDate,
  }) {
    return ReviewCardsCompanion(
      id: id ?? this.id,
      repertoireId: repertoireId ?? this.repertoireId,
      leafMoveId: leafMoveId ?? this.leafMoveId,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastQuality: lastQuality ?? this.lastQuality,
      lastExtraPracticeDate:
          lastExtraPracticeDate ?? this.lastExtraPracticeDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repertoireId.present) {
      map['repertoire_id'] = Variable<int>(repertoireId.value);
    }
    if (leafMoveId.present) {
      map['leaf_move_id'] = Variable<int>(leafMoveId.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (nextReviewDate.present) {
      map['next_review_date'] = Variable<DateTime>(nextReviewDate.value);
    }
    if (lastQuality.present) {
      map['last_quality'] = Variable<int>(lastQuality.value);
    }
    if (lastExtraPracticeDate.present) {
      map['last_extra_practice_date'] = Variable<DateTime>(
        lastExtraPracticeDate.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewCardsCompanion(')
          ..write('id: $id, ')
          ..write('repertoireId: $repertoireId, ')
          ..write('leafMoveId: $leafMoveId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('nextReviewDate: $nextReviewDate, ')
          ..write('lastQuality: $lastQuality, ')
          ..write('lastExtraPracticeDate: $lastExtraPracticeDate')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RepertoiresTable repertoires = $RepertoiresTable(this);
  late final $RepertoireMovesTable repertoireMoves = $RepertoireMovesTable(
    this,
  );
  late final $ReviewCardsTable reviewCards = $ReviewCardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    repertoires,
    repertoireMoves,
    reviewCards,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'repertoires',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('repertoire_moves', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'repertoire_moves',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('repertoire_moves', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'repertoires',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'repertoire_moves',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_cards', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RepertoiresTableCreateCompanionBuilder =
    RepertoiresCompanion Function({Value<int> id, required String name});
typedef $$RepertoiresTableUpdateCompanionBuilder =
    RepertoiresCompanion Function({Value<int> id, Value<String> name});

final class $$RepertoiresTableReferences
    extends BaseReferences<_$AppDatabase, $RepertoiresTable, Repertoire> {
  $$RepertoiresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RepertoireMovesTable, List<RepertoireMove>>
  _repertoireMovesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.repertoireMoves,
    aliasName: $_aliasNameGenerator(
      db.repertoires.id,
      db.repertoireMoves.repertoireId,
    ),
  );

  $$RepertoireMovesTableProcessedTableManager get repertoireMovesRefs {
    final manager = $$RepertoireMovesTableTableManager(
      $_db,
      $_db.repertoireMoves,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _repertoireMovesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReviewCardsTable, List<ReviewCard>>
  _reviewCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewCards,
    aliasName: $_aliasNameGenerator(
      db.repertoires.id,
      db.reviewCards.repertoireId,
    ),
  );

  $$ReviewCardsTableProcessedTableManager get reviewCardsRefs {
    final manager = $$ReviewCardsTableTableManager(
      $_db,
      $_db.reviewCards,
    ).filter((f) => f.repertoireId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RepertoiresTableFilterComposer
    extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableFilterComposer({
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

  Expression<bool> repertoireMovesRefs(
    Expression<bool> Function($$RepertoireMovesTableFilterComposer f) f,
  ) {
    final $$RepertoireMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.repertoireId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableFilterComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reviewCardsRefs(
    Expression<bool> Function($$ReviewCardsTableFilterComposer f) f,
  ) {
    final $$ReviewCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.repertoireId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableFilterComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoiresTableOrderingComposer
    extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableOrderingComposer({
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
}

class $$RepertoiresTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepertoiresTable> {
  $$RepertoiresTableAnnotationComposer({
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

  Expression<T> repertoireMovesRefs<T extends Object>(
    Expression<T> Function($$RepertoireMovesTableAnnotationComposer a) f,
  ) {
    final $$RepertoireMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.repertoireId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reviewCardsRefs<T extends Object>(
    Expression<T> Function($$ReviewCardsTableAnnotationComposer a) f,
  ) {
    final $$ReviewCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.repertoireId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoiresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepertoiresTable,
          Repertoire,
          $$RepertoiresTableFilterComposer,
          $$RepertoiresTableOrderingComposer,
          $$RepertoiresTableAnnotationComposer,
          $$RepertoiresTableCreateCompanionBuilder,
          $$RepertoiresTableUpdateCompanionBuilder,
          (Repertoire, $$RepertoiresTableReferences),
          Repertoire,
          PrefetchHooks Function({
            bool repertoireMovesRefs,
            bool reviewCardsRefs,
          })
        > {
  $$RepertoiresTableTableManager(_$AppDatabase db, $RepertoiresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepertoiresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepertoiresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepertoiresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => RepertoiresCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  RepertoiresCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RepertoiresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({repertoireMovesRefs = false, reviewCardsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (repertoireMovesRefs) db.repertoireMoves,
                    if (reviewCardsRefs) db.reviewCards,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (repertoireMovesRefs)
                        await $_getPrefetchedData<
                          Repertoire,
                          $RepertoiresTable,
                          RepertoireMove
                        >(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences
                              ._repertoireMovesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepertoiresTableReferences(
                                db,
                                table,
                                p0,
                              ).repertoireMovesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repertoireId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (reviewCardsRefs)
                        await $_getPrefetchedData<
                          Repertoire,
                          $RepertoiresTable,
                          ReviewCard
                        >(
                          currentTable: table,
                          referencedTable: $$RepertoiresTableReferences
                              ._reviewCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepertoiresTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewCardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repertoireId == item.id,
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

typedef $$RepertoiresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepertoiresTable,
      Repertoire,
      $$RepertoiresTableFilterComposer,
      $$RepertoiresTableOrderingComposer,
      $$RepertoiresTableAnnotationComposer,
      $$RepertoiresTableCreateCompanionBuilder,
      $$RepertoiresTableUpdateCompanionBuilder,
      (Repertoire, $$RepertoiresTableReferences),
      Repertoire,
      PrefetchHooks Function({bool repertoireMovesRefs, bool reviewCardsRefs})
    >;
typedef $$RepertoireMovesTableCreateCompanionBuilder =
    RepertoireMovesCompanion Function({
      Value<int> id,
      required int repertoireId,
      Value<int?> parentMoveId,
      required String fen,
      required String san,
      Value<String?> label,
      Value<String?> comment,
      required int sortOrder,
    });
typedef $$RepertoireMovesTableUpdateCompanionBuilder =
    RepertoireMovesCompanion Function({
      Value<int> id,
      Value<int> repertoireId,
      Value<int?> parentMoveId,
      Value<String> fen,
      Value<String> san,
      Value<String?> label,
      Value<String?> comment,
      Value<int> sortOrder,
    });

final class $$RepertoireMovesTableReferences
    extends
        BaseReferences<_$AppDatabase, $RepertoireMovesTable, RepertoireMove> {
  $$RepertoireMovesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias(
        $_aliasNameGenerator(
          db.repertoireMoves.repertoireId,
          db.repertoires.id,
        ),
      );

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager(
      $_db,
      $_db.repertoires,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepertoireMovesTable _parentMoveIdTable(_$AppDatabase db) =>
      db.repertoireMoves.createAlias(
        $_aliasNameGenerator(
          db.repertoireMoves.parentMoveId,
          db.repertoireMoves.id,
        ),
      );

  $$RepertoireMovesTableProcessedTableManager? get parentMoveId {
    final $_column = $_itemColumn<int>('parent_move_id');
    if ($_column == null) return null;
    final manager = $$RepertoireMovesTableTableManager(
      $_db,
      $_db.repertoireMoves,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentMoveIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReviewCardsTable, List<ReviewCard>>
  _reviewCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewCards,
    aliasName: $_aliasNameGenerator(
      db.repertoireMoves.id,
      db.reviewCards.leafMoveId,
    ),
  );

  $$ReviewCardsTableProcessedTableManager get reviewCardsRefs {
    final manager = $$ReviewCardsTableTableManager(
      $_db,
      $_db.reviewCards,
    ).filter((f) => f.leafMoveId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RepertoireMovesTableFilterComposer
    extends Composer<_$AppDatabase, $RepertoireMovesTable> {
  $$RepertoireMovesTableFilterComposer({
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

  ColumnFilters<String> get fen => $composableBuilder(
    column: $table.fen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get san => $composableBuilder(
    column: $table.san,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableFilterComposer get parentMoveId {
    final $$RepertoireMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableFilterComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> reviewCardsRefs(
    Expression<bool> Function($$ReviewCardsTableFilterComposer f) f,
  ) {
    final $$ReviewCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.leafMoveId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableFilterComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoireMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $RepertoireMovesTable> {
  $$RepertoireMovesTableOrderingComposer({
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

  ColumnOrderings<String> get fen => $composableBuilder(
    column: $table.fen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get san => $composableBuilder(
    column: $table.san,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableOrderingComposer get parentMoveId {
    final $$RepertoireMovesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableOrderingComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RepertoireMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepertoireMovesTable> {
  $$RepertoireMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fen =>
      $composableBuilder(column: $table.fen, builder: (column) => column);

  GeneratedColumn<String> get san =>
      $composableBuilder(column: $table.san, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableAnnotationComposer get parentMoveId {
    final $$RepertoireMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> reviewCardsRefs<T extends Object>(
    Expression<T> Function($$ReviewCardsTableAnnotationComposer a) f,
  ) {
    final $$ReviewCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewCards,
      getReferencedColumn: (t) => t.leafMoveId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepertoireMovesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepertoireMovesTable,
          RepertoireMove,
          $$RepertoireMovesTableFilterComposer,
          $$RepertoireMovesTableOrderingComposer,
          $$RepertoireMovesTableAnnotationComposer,
          $$RepertoireMovesTableCreateCompanionBuilder,
          $$RepertoireMovesTableUpdateCompanionBuilder,
          (RepertoireMove, $$RepertoireMovesTableReferences),
          RepertoireMove,
          PrefetchHooks Function({
            bool repertoireId,
            bool parentMoveId,
            bool reviewCardsRefs,
          })
        > {
  $$RepertoireMovesTableTableManager(
    _$AppDatabase db,
    $RepertoireMovesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepertoireMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepertoireMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepertoireMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repertoireId = const Value.absent(),
                Value<int?> parentMoveId = const Value.absent(),
                Value<String> fen = const Value.absent(),
                Value<String> san = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => RepertoireMovesCompanion(
                id: id,
                repertoireId: repertoireId,
                parentMoveId: parentMoveId,
                fen: fen,
                san: san,
                label: label,
                comment: comment,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repertoireId,
                Value<int?> parentMoveId = const Value.absent(),
                required String fen,
                required String san,
                Value<String?> label = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                required int sortOrder,
              }) => RepertoireMovesCompanion.insert(
                id: id,
                repertoireId: repertoireId,
                parentMoveId: parentMoveId,
                fen: fen,
                san: san,
                label: label,
                comment: comment,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RepertoireMovesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                repertoireId = false,
                parentMoveId = false,
                reviewCardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reviewCardsRefs) db.reviewCards,
                  ],
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
                        if (repertoireId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.repertoireId,
                                    referencedTable:
                                        $$RepertoireMovesTableReferences
                                            ._repertoireIdTable(db),
                                    referencedColumn:
                                        $$RepertoireMovesTableReferences
                                            ._repertoireIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (parentMoveId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentMoveId,
                                    referencedTable:
                                        $$RepertoireMovesTableReferences
                                            ._parentMoveIdTable(db),
                                    referencedColumn:
                                        $$RepertoireMovesTableReferences
                                            ._parentMoveIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reviewCardsRefs)
                        await $_getPrefetchedData<
                          RepertoireMove,
                          $RepertoireMovesTable,
                          ReviewCard
                        >(
                          currentTable: table,
                          referencedTable: $$RepertoireMovesTableReferences
                              ._reviewCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepertoireMovesTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewCardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.leafMoveId == item.id,
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

typedef $$RepertoireMovesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepertoireMovesTable,
      RepertoireMove,
      $$RepertoireMovesTableFilterComposer,
      $$RepertoireMovesTableOrderingComposer,
      $$RepertoireMovesTableAnnotationComposer,
      $$RepertoireMovesTableCreateCompanionBuilder,
      $$RepertoireMovesTableUpdateCompanionBuilder,
      (RepertoireMove, $$RepertoireMovesTableReferences),
      RepertoireMove,
      PrefetchHooks Function({
        bool repertoireId,
        bool parentMoveId,
        bool reviewCardsRefs,
      })
    >;
typedef $$ReviewCardsTableCreateCompanionBuilder =
    ReviewCardsCompanion Function({
      Value<int> id,
      required int repertoireId,
      required int leafMoveId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      required DateTime nextReviewDate,
      Value<int?> lastQuality,
      Value<DateTime?> lastExtraPracticeDate,
    });
typedef $$ReviewCardsTableUpdateCompanionBuilder =
    ReviewCardsCompanion Function({
      Value<int> id,
      Value<int> repertoireId,
      Value<int> leafMoveId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      Value<DateTime> nextReviewDate,
      Value<int?> lastQuality,
      Value<DateTime?> lastExtraPracticeDate,
    });

final class $$ReviewCardsTableReferences
    extends BaseReferences<_$AppDatabase, $ReviewCardsTable, ReviewCard> {
  $$ReviewCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepertoiresTable _repertoireIdTable(_$AppDatabase db) =>
      db.repertoires.createAlias(
        $_aliasNameGenerator(db.reviewCards.repertoireId, db.repertoires.id),
      );

  $$RepertoiresTableProcessedTableManager get repertoireId {
    final $_column = $_itemColumn<int>('repertoire_id')!;

    final manager = $$RepertoiresTableTableManager(
      $_db,
      $_db.repertoires,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repertoireIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepertoireMovesTable _leafMoveIdTable(_$AppDatabase db) =>
      db.repertoireMoves.createAlias(
        $_aliasNameGenerator(db.reviewCards.leafMoveId, db.repertoireMoves.id),
      );

  $$RepertoireMovesTableProcessedTableManager get leafMoveId {
    final $_column = $_itemColumn<int>('leaf_move_id')!;

    final manager = $$RepertoireMovesTableTableManager(
      $_db,
      $_db.repertoireMoves,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_leafMoveIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewCardsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableFilterComposer({
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

  ColumnFilters<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastQuality => $composableBuilder(
    column: $table.lastQuality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastExtraPracticeDate => $composableBuilder(
    column: $table.lastExtraPracticeDate,
    builder: (column) => ColumnFilters(column),
  );

  $$RepertoiresTableFilterComposer get repertoireId {
    final $$RepertoiresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableFilterComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableFilterComposer get leafMoveId {
    final $$RepertoireMovesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leafMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableFilterComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableOrderingComposer({
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

  ColumnOrderings<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastQuality => $composableBuilder(
    column: $table.lastQuality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastExtraPracticeDate => $composableBuilder(
    column: $table.lastExtraPracticeDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepertoiresTableOrderingComposer get repertoireId {
    final $$RepertoiresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableOrderingComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableOrderingComposer get leafMoveId {
    final $$RepertoireMovesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leafMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableOrderingComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewCardsTable> {
  $$ReviewCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextReviewDate => $composableBuilder(
    column: $table.nextReviewDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastQuality => $composableBuilder(
    column: $table.lastQuality,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastExtraPracticeDate => $composableBuilder(
    column: $table.lastExtraPracticeDate,
    builder: (column) => column,
  );

  $$RepertoiresTableAnnotationComposer get repertoireId {
    final $$RepertoiresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repertoireId,
      referencedTable: $db.repertoires,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoiresTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoires,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepertoireMovesTableAnnotationComposer get leafMoveId {
    final $$RepertoireMovesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leafMoveId,
      referencedTable: $db.repertoireMoves,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepertoireMovesTableAnnotationComposer(
            $db: $db,
            $table: $db.repertoireMoves,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewCardsTable,
          ReviewCard,
          $$ReviewCardsTableFilterComposer,
          $$ReviewCardsTableOrderingComposer,
          $$ReviewCardsTableAnnotationComposer,
          $$ReviewCardsTableCreateCompanionBuilder,
          $$ReviewCardsTableUpdateCompanionBuilder,
          (ReviewCard, $$ReviewCardsTableReferences),
          ReviewCard,
          PrefetchHooks Function({bool repertoireId, bool leafMoveId})
        > {
  $$ReviewCardsTableTableManager(_$AppDatabase db, $ReviewCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repertoireId = const Value.absent(),
                Value<int> leafMoveId = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<DateTime> nextReviewDate = const Value.absent(),
                Value<int?> lastQuality = const Value.absent(),
                Value<DateTime?> lastExtraPracticeDate = const Value.absent(),
              }) => ReviewCardsCompanion(
                id: id,
                repertoireId: repertoireId,
                leafMoveId: leafMoveId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                nextReviewDate: nextReviewDate,
                lastQuality: lastQuality,
                lastExtraPracticeDate: lastExtraPracticeDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repertoireId,
                required int leafMoveId,
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                required DateTime nextReviewDate,
                Value<int?> lastQuality = const Value.absent(),
                Value<DateTime?> lastExtraPracticeDate = const Value.absent(),
              }) => ReviewCardsCompanion.insert(
                id: id,
                repertoireId: repertoireId,
                leafMoveId: leafMoveId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                nextReviewDate: nextReviewDate,
                lastQuality: lastQuality,
                lastExtraPracticeDate: lastExtraPracticeDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReviewCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({repertoireId = false, leafMoveId = false}) {
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
                    if (repertoireId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repertoireId,
                                referencedTable: $$ReviewCardsTableReferences
                                    ._repertoireIdTable(db),
                                referencedColumn: $$ReviewCardsTableReferences
                                    ._repertoireIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (leafMoveId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.leafMoveId,
                                referencedTable: $$ReviewCardsTableReferences
                                    ._leafMoveIdTable(db),
                                referencedColumn: $$ReviewCardsTableReferences
                                    ._leafMoveIdTable(db)
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

typedef $$ReviewCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewCardsTable,
      ReviewCard,
      $$ReviewCardsTableFilterComposer,
      $$ReviewCardsTableOrderingComposer,
      $$ReviewCardsTableAnnotationComposer,
      $$ReviewCardsTableCreateCompanionBuilder,
      $$ReviewCardsTableUpdateCompanionBuilder,
      (ReviewCard, $$ReviewCardsTableReferences),
      ReviewCard,
      PrefetchHooks Function({bool repertoireId, bool leafMoveId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RepertoiresTableTableManager get repertoires =>
      $$RepertoiresTableTableManager(_db, _db.repertoires);
  $$RepertoireMovesTableTableManager get repertoireMoves =>
      $$RepertoireMovesTableTableManager(_db, _db.repertoireMoves);
  $$ReviewCardsTableTableManager get reviewCards =>
      $$ReviewCardsTableTableManager(_db, _db.reviewCards);
}
