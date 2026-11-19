// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// ignore_for_file: type=lint
class $NotebookTableTable extends NotebookTable
    with TableInfo<$NotebookTableTable, Notebook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotebookTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, sort, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notebook';
  @override
  VerificationContext validateIntegrity(
    Insertable<Notebook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notebook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notebook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NotebookTableTable createAlias(String alias) {
    return $NotebookTableTable(attachedDatabase, alias);
  }
}

class Notebook extends DataClass implements Insertable<Notebook> {
  final String id;
  final String name;
  final String? color;
  final int sort;
  final int createdAt;
  const Notebook({
    required this.id,
    required this.name,
    this.color,
    required this.sort,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort'] = Variable<int>(sort);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  NotebookTableCompanion toCompanion(bool nullToAbsent) {
    return NotebookTableCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sort: Value(sort),
      createdAt: Value(createdAt),
    );
  }

  factory Notebook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notebook(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      sort: serializer.fromJson<int>(json['sort']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'sort': serializer.toJson<int>(sort),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Notebook copyWith({
    String? id,
    String? name,
    Value<String?> color = const Value.absent(),
    int? sort,
    int? createdAt,
  }) => Notebook(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    sort: sort ?? this.sort,
    createdAt: createdAt ?? this.createdAt,
  );
  Notebook copyWithCompanion(NotebookTableCompanion data) {
    return Notebook(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sort: data.sort.present ? data.sort.value : this.sort,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Notebook(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, sort, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notebook &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sort == this.sort &&
          other.createdAt == this.createdAt);
}

class NotebookTableCompanion extends UpdateCompanion<Notebook> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> color;
  final Value<int> sort;
  final Value<int> createdAt;
  final Value<int> rowid;
  const NotebookTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sort = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotebookTableCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.sort = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Notebook> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? sort,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sort != null) 'sort': sort,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotebookTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? color,
    Value<int>? sort,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return NotebookTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sort: sort ?? this.sort,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotebookTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sort: $sort, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTableTable extends NoteTable with TableInfo<$NoteTableTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notebookIdMeta = const VerificationMeta(
    'notebookId',
  );
  @override
  late final GeneratedColumn<String> notebookId = GeneratedColumn<String>(
    'notebook_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notebook (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<int> pinned = GeneratedColumn<int>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    notebookId,
    title,
    body,
    createdAt,
    updatedAt,
    pinned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('notebook_id')) {
      context.handle(
        _notebookIdMeta,
        notebookId.isAcceptableOrUnknown(data['notebook_id']!, _notebookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_notebookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      notebookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notebook_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned'],
      )!,
    );
  }

  @override
  $NoteTableTable createAlias(String alias) {
    return $NoteTableTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String notebookId;
  final String? title;
  final String? body;
  final int createdAt;
  final int updatedAt;
  final int pinned;
  const Note({
    required this.id,
    required this.notebookId,
    this.title,
    this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['notebook_id'] = Variable<String>(notebookId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['pinned'] = Variable<int>(pinned);
    return map;
  }

  NoteTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTableCompanion(
      id: Value(id),
      notebookId: Value(notebookId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pinned: Value(pinned),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      notebookId: serializer.fromJson<String>(json['notebookId']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      pinned: serializer.fromJson<int>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'notebookId': serializer.toJson<String>(notebookId),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'pinned': serializer.toJson<int>(pinned),
    };
  }

  Note copyWith({
    String? id,
    String? notebookId,
    Value<String?> title = const Value.absent(),
    Value<String?> body = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    int? pinned,
  }) => Note(
    id: id ?? this.id,
    notebookId: notebookId ?? this.notebookId,
    title: title.present ? title.value : this.title,
    body: body.present ? body.value : this.body,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pinned: pinned ?? this.pinned,
  );
  Note copyWithCompanion(NoteTableCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      notebookId: data.notebookId.present
          ? data.notebookId.value
          : this.notebookId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, notebookId, title, body, createdAt, updatedAt, pinned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.notebookId == this.notebookId &&
          other.title == this.title &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pinned == this.pinned);
}

class NoteTableCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> notebookId;
  final Value<String?> title;
  final Value<String?> body;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> pinned;
  final Value<int> rowid;
  const NoteTableCompanion({
    this.id = const Value.absent(),
    this.notebookId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTableCompanion.insert({
    required String id,
    required String notebookId,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       notebookId = Value(notebookId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? notebookId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? pinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (notebookId != null) 'notebook_id': notebookId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pinned != null) 'pinned': pinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTableCompanion copyWith({
    Value<String>? id,
    Value<String>? notebookId,
    Value<String?>? title,
    Value<String?>? body,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? pinned,
    Value<int>? rowid,
  }) {
    return NoteTableCompanion(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (notebookId.present) {
      map['notebook_id'] = Variable<String>(notebookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<int>(pinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableCompanion(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentTableTable extends AttachmentTable
    with TableInfo<$AttachmentTableTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES note (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    path,
    mime,
    width,
    height,
    sha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachment';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
    );
  }

  @override
  $AttachmentTableTable createAlias(String alias) {
    return $AttachmentTableTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String noteId;
  final String path;
  final String? mime;
  final int? width;
  final int? height;
  final String sha256;
  const Attachment({
    required this.id,
    required this.noteId,
    required this.path,
    this.mime,
    this.width,
    this.height,
    required this.sha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['sha256'] = Variable<String>(sha256);
    return map;
  }

  AttachmentTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      path: Value(path),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      sha256: Value(sha256),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      path: serializer.fromJson<String>(json['path']),
      mime: serializer.fromJson<String?>(json['mime']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      sha256: serializer.fromJson<String>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'path': serializer.toJson<String>(path),
      'mime': serializer.toJson<String?>(mime),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'sha256': serializer.toJson<String>(sha256),
    };
  }

  Attachment copyWith({
    String? id,
    String? noteId,
    String? path,
    Value<String?> mime = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    String? sha256,
  }) => Attachment(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    path: path ?? this.path,
    mime: mime.present ? mime.value : this.mime,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    sha256: sha256 ?? this.sha256,
  );
  Attachment copyWithCompanion(AttachmentTableCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      path: data.path.present ? data.path.value : this.path,
      mime: data.mime.present ? data.mime.value : this.mime,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, noteId, path, mime, width, height, sha256);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.path == this.path &&
          other.mime == this.mime &&
          other.width == this.width &&
          other.height == this.height &&
          other.sha256 == this.sha256);
}

class AttachmentTableCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> path;
  final Value<String?> mime;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String> sha256;
  final Value<int> rowid;
  const AttachmentTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentTableCompanion.insert({
    required String id,
    required String noteId,
    required String path,
    this.mime = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required String sha256,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       path = Value(path),
       sha256 = Value(sha256);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? path,
    Expression<String>? mime,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? sha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (path != null) 'path': path,
      if (mime != null) 'mime': mime,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sha256 != null) 'sha256': sha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentTableCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? path,
    Value<String?>? mime,
    Value<int?>? width,
    Value<int?>? height,
    Value<String>? sha256,
    Value<int>? rowid,
  }) {
    return AttachmentTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      path: path ?? this.path,
      mime: mime ?? this.mime,
      width: width ?? this.width,
      height: height ?? this.height,
      sha256: sha256 ?? this.sha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sha256: $sha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTableTable extends MetaTable with TableInfo<$MetaTableTable, Meta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Meta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meta(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $MetaTableTable createAlias(String alias) {
    return $MetaTableTable(attachedDatabase, alias);
  }
}

class Meta extends DataClass implements Insertable<Meta> {
  final String key;
  final String? value;
  const Meta({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  MetaTableCompanion toCompanion(bool nullToAbsent) {
    return MetaTableCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory Meta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meta(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  Meta copyWith({String? key, Value<String?> value = const Value.absent()}) =>
      Meta(
        key: key ?? this.key,
        value: value.present ? value.value : this.value,
      );
  Meta copyWithCompanion(MetaTableCompanion data) {
    return Meta(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meta(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meta && other.key == this.key && other.value == this.value);
}

class MetaTableCompanion extends UpdateCompanion<Meta> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const MetaTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaTableCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Meta> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaTableCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return MetaTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EnvxSchema extends GeneratedDatabase {
  _$EnvxSchema(QueryExecutor e) : super(e);
  $EnvxSchemaManager get managers => $EnvxSchemaManager(this);
  late final $NotebookTableTable notebookTable = $NotebookTableTable(this);
  late final $NoteTableTable noteTable = $NoteTableTable(this);
  late final $AttachmentTableTable attachmentTable = $AttachmentTableTable(
    this,
  );
  late final $MetaTableTable metaTable = $MetaTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    notebookTable,
    noteTable,
    attachmentTable,
    metaTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notebook',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'note',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachment', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NotebookTableTableCreateCompanionBuilder =
    NotebookTableCompanion Function({
      required String id,
      required String name,
      Value<String?> color,
      Value<int> sort,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$NotebookTableTableUpdateCompanionBuilder =
    NotebookTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> color,
      Value<int> sort,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$NotebookTableTableReferences
    extends BaseReferences<_$EnvxSchema, $NotebookTableTable, Notebook> {
  $$NotebookTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$NoteTableTable, List<Note>> _noteTableRefsTable(
    _$EnvxSchema db,
  ) => MultiTypedResultKey.fromTable(
    db.noteTable,
    aliasName: 'notebook__id__note__notebook_id',
  );

  $$NoteTableTableProcessedTableManager get noteTableRefs {
    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.notebookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotebookTableTableFilterComposer
    extends Composer<_$EnvxSchema, $NotebookTableTable> {
  $$NotebookTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTableRefs(
    Expression<bool> Function($$NoteTableTableFilterComposer f) f,
  ) {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.notebookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotebookTableTableOrderingComposer
    extends Composer<_$EnvxSchema, $NotebookTableTable> {
  $$NotebookTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotebookTableTableAnnotationComposer
    extends Composer<_$EnvxSchema, $NotebookTableTable> {
  $$NotebookTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> noteTableRefs<T extends Object>(
    Expression<T> Function($$NoteTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.notebookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotebookTableTableTableManager
    extends
        RootTableManager<
          _$EnvxSchema,
          $NotebookTableTable,
          Notebook,
          $$NotebookTableTableFilterComposer,
          $$NotebookTableTableOrderingComposer,
          $$NotebookTableTableAnnotationComposer,
          $$NotebookTableTableCreateCompanionBuilder,
          $$NotebookTableTableUpdateCompanionBuilder,
          (Notebook, $$NotebookTableTableReferences),
          Notebook,
          PrefetchHooks Function({bool noteTableRefs})
        > {
  $$NotebookTableTableTableManager(_$EnvxSchema db, $NotebookTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotebookTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotebookTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotebookTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotebookTableCompanion(
                id: id,
                name: name,
                color: color,
                sort: sort,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> color = const Value.absent(),
                Value<int> sort = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NotebookTableCompanion.insert(
                id: id,
                name: name,
                color: color,
                sort: sort,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotebookTableTable, Notebook>(table),
                  $$NotebookTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTableRefs) db.noteTable],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTableRefs)
                    await $_getPrefetchedDataByColumns<
                      Notebook,
                      $NotebookTableTable,
                      Note,
                      $NoteTableTable
                    >(
                      currentTable: table,
                      referencedTable: $$NotebookTableTableReferences
                          ._noteTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NotebookTableTableReferences(
                            db,
                            table,
                            p0,
                          ).noteTableRefs,
                      currentColumn: 'id',
                      referencedColumn: 'notebook_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NotebookTableTableProcessedTableManager =
    ProcessedTableManager<
      _$EnvxSchema,
      $NotebookTableTable,
      Notebook,
      $$NotebookTableTableFilterComposer,
      $$NotebookTableTableOrderingComposer,
      $$NotebookTableTableAnnotationComposer,
      $$NotebookTableTableCreateCompanionBuilder,
      $$NotebookTableTableUpdateCompanionBuilder,
      (Notebook, $$NotebookTableTableReferences),
      Notebook,
      PrefetchHooks Function({bool noteTableRefs})
    >;
typedef $$NoteTableTableCreateCompanionBuilder = NoteTableCompanion Function({
  required String id,
  required String notebookId,
  Value<String?> title,
  Value<String?> body,
  required int createdAt,
  required int updatedAt,
  Value<int> pinned,
  Value<int> rowid,
});
typedef $$NoteTableTableUpdateCompanionBuilder = NoteTableCompanion Function({
  Value<String> id,
  Value<String> notebookId,
  Value<String?> title,
  Value<String?> body,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> pinned,
  Value<int> rowid,
});

final class $$NoteTableTableReferences
    extends BaseReferences<_$EnvxSchema, $NoteTableTable, Note> {
  $$NoteTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotebookTableTable _notebookIdTable(_$EnvxSchema db) =>
      db.notebookTable.createAlias('note__notebook_id__notebook__id');

  $$NotebookTableTableProcessedTableManager get notebookId {
    final $_column = $_itemColumn<String>('notebook_id')!;

    final manager = $$NotebookTableTableTableManager(
      $_db,
      $_db.notebookTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_notebookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AttachmentTableTable, List<Attachment>>
  _attachmentTableRefsTable(_$EnvxSchema db) => MultiTypedResultKey.fromTable(
    db.attachmentTable,
    aliasName: 'note__id__attachment__note_id',
  );

  $$AttachmentTableTableProcessedTableManager get attachmentTableRefs {
    final manager = $$AttachmentTableTableTableManager(
      $_db,
      $_db.attachmentTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attachmentTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NoteTableTableFilterComposer
    extends Composer<_$EnvxSchema, $NoteTableTable> {
  $$NoteTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  $$NotebookTableTableFilterComposer get notebookId {
    final $$NotebookTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookTableTableFilterComposer(
            $db: $db,
            $table: $db.notebookTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attachmentTableRefs(
    Expression<bool> Function($$AttachmentTableTableFilterComposer f) f,
  ) {
    final $$AttachmentTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentTableTableFilterComposer(
            $db: $db,
            $table: $db.attachmentTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableOrderingComposer
    extends Composer<_$EnvxSchema, $NoteTableTable> {
  $$NoteTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotebookTableTableOrderingComposer get notebookId {
    final $$NotebookTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookTableTableOrderingComposer(
            $db: $db,
            $table: $db.notebookTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTableTableAnnotationComposer
    extends Composer<_$EnvxSchema, $NoteTableTable> {
  $$NoteTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  $$NotebookTableTableAnnotationComposer get notebookId {
    final $$NotebookTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookTableTableAnnotationComposer(
            $db: $db,
            $table: $db.notebookTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attachmentTableRefs<T extends Object>(
    Expression<T> Function($$AttachmentTableTableAnnotationComposer a) f,
  ) {
    final $$AttachmentTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentTableTableAnnotationComposer(
            $db: $db,
            $table: $db.attachmentTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableTableManager
    extends
        RootTableManager<
          _$EnvxSchema,
          $NoteTableTable,
          Note,
          $$NoteTableTableFilterComposer,
          $$NoteTableTableOrderingComposer,
          $$NoteTableTableAnnotationComposer,
          $$NoteTableTableCreateCompanionBuilder,
          $$NoteTableTableUpdateCompanionBuilder,
          (Note, $$NoteTableTableReferences),
          Note,
          PrefetchHooks Function({bool notebookId, bool attachmentTableRefs})
        > {
  $$NoteTableTableTableManager(_$EnvxSchema db, $NoteTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> notebookId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTableCompanion(
                id: id,
                notebookId: notebookId,
                title: title,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String notebookId,
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTableCompanion.insert(
                id: id,
                notebookId: notebookId,
                title: title,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTableTable, Note>(table),
                  $$NoteTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({notebookId = false, attachmentTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attachmentTableRefs) db.attachmentTable,
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
                        if (notebookId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.notebookId,
                            referencedTable: $$NoteTableTableReferences
                                ._notebookIdTable(db),
                            referencedColumn: $$NoteTableTableReferences
                                ._notebookIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attachmentTableRefs)
                        await $_getPrefetchedDataByColumns<
                          Note,
                          $NoteTableTable,
                          Attachment,
                          $AttachmentTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$NoteTableTableReferences
                              ._attachmentTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NoteTableTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentTableRefs,
                          currentColumn: 'id',
                          referencedColumn: 'note_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NoteTableTableProcessedTableManager =
    ProcessedTableManager<
      _$EnvxSchema,
      $NoteTableTable,
      Note,
      $$NoteTableTableFilterComposer,
      $$NoteTableTableOrderingComposer,
      $$NoteTableTableAnnotationComposer,
      $$NoteTableTableCreateCompanionBuilder,
      $$NoteTableTableUpdateCompanionBuilder,
      (Note, $$NoteTableTableReferences),
      Note,
      PrefetchHooks Function({bool notebookId, bool attachmentTableRefs})
    >;
typedef $$AttachmentTableTableCreateCompanionBuilder =
    AttachmentTableCompanion Function({
      required String id,
      required String noteId,
      required String path,
      Value<String?> mime,
      Value<int?> width,
      Value<int?> height,
      required String sha256,
      Value<int> rowid,
    });
typedef $$AttachmentTableTableUpdateCompanionBuilder =
    AttachmentTableCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> path,
      Value<String?> mime,
      Value<int?> width,
      Value<int?> height,
      Value<String> sha256,
      Value<int> rowid,
    });

final class $$AttachmentTableTableReferences
    extends BaseReferences<_$EnvxSchema, $AttachmentTableTable, Attachment> {
  $$AttachmentTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NoteTableTable _noteIdTable(_$EnvxSchema db) =>
      db.noteTable.createAlias('attachment__note_id__note__id');

  $$NoteTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentTableTableFilterComposer
    extends Composer<_$EnvxSchema, $AttachmentTableTable> {
  $$AttachmentTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  $$NoteTableTableFilterComposer get noteId {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableOrderingComposer
    extends Composer<_$EnvxSchema, $AttachmentTableTable> {
  $$AttachmentTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$NoteTableTableOrderingComposer get noteId {
    final $$NoteTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableOrderingComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableAnnotationComposer
    extends Composer<_$EnvxSchema, $AttachmentTableTable> {
  $$AttachmentTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  $$NoteTableTableAnnotationComposer get noteId {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableTableManager
    extends
        RootTableManager<
          _$EnvxSchema,
          $AttachmentTableTable,
          Attachment,
          $$AttachmentTableTableFilterComposer,
          $$AttachmentTableTableOrderingComposer,
          $$AttachmentTableTableAnnotationComposer,
          $$AttachmentTableTableCreateCompanionBuilder,
          $$AttachmentTableTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentTableTableReferences),
          Attachment,
          PrefetchHooks Function({bool noteId})
        > {
  $$AttachmentTableTableTableManager(
    _$EnvxSchema db,
    $AttachmentTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentTableCompanion(
                id: id,
                noteId: noteId,
                path: path,
                mime: mime,
                width: width,
                height: height,
                sha256: sha256,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String path,
                Value<String?> mime = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required String sha256,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentTableCompanion.insert(
                id: id,
                noteId: noteId,
                path: path,
                mime: mime,
                width: width,
                height: height,
                sha256: sha256,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentTableTable, Attachment>(table),
                  $$AttachmentTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
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
                    if (noteId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.noteId,
                        referencedTable: $$AttachmentTableTableReferences
                            ._noteIdTable(db),
                        referencedColumn: $$AttachmentTableTableReferences
                            ._noteIdTable(db)
                            .id,
                      ) as T;
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

typedef $$AttachmentTableTableProcessedTableManager =
    ProcessedTableManager<
      _$EnvxSchema,
      $AttachmentTableTable,
      Attachment,
      $$AttachmentTableTableFilterComposer,
      $$AttachmentTableTableOrderingComposer,
      $$AttachmentTableTableAnnotationComposer,
      $$AttachmentTableTableCreateCompanionBuilder,
      $$AttachmentTableTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentTableTableReferences),
      Attachment,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$MetaTableTableCreateCompanionBuilder = MetaTableCompanion Function({
  required String key,
  Value<String?> value,
  Value<int> rowid,
});
typedef $$MetaTableTableUpdateCompanionBuilder = MetaTableCompanion Function({
  Value<String> key,
  Value<String?> value,
  Value<int> rowid,
});

class $$MetaTableTableFilterComposer
    extends Composer<_$EnvxSchema, $MetaTableTable> {
  $$MetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableTableOrderingComposer
    extends Composer<_$EnvxSchema, $MetaTableTable> {
  $$MetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableTableAnnotationComposer
    extends Composer<_$EnvxSchema, $MetaTableTable> {
  $$MetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableTableManager
    extends
        RootTableManager<
          _$EnvxSchema,
          $MetaTableTable,
          Meta,
          $$MetaTableTableFilterComposer,
          $$MetaTableTableOrderingComposer,
          $$MetaTableTableAnnotationComposer,
          $$MetaTableTableCreateCompanionBuilder,
          $$MetaTableTableUpdateCompanionBuilder,
          (Meta, BaseReferences<_$EnvxSchema, $MetaTableTable, Meta>),
          Meta,
          PrefetchHooks Function()
        > {
  $$MetaTableTableTableManager(_$EnvxSchema db, $MetaTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaTableCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTableTable, Meta>(table),
                  BaseReferences<_$EnvxSchema, $MetaTableTable, Meta>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$EnvxSchema,
      $MetaTableTable,
      Meta,
      $$MetaTableTableFilterComposer,
      $$MetaTableTableOrderingComposer,
      $$MetaTableTableAnnotationComposer,
      $$MetaTableTableCreateCompanionBuilder,
      $$MetaTableTableUpdateCompanionBuilder,
      (Meta, BaseReferences<_$EnvxSchema, $MetaTableTable, Meta>),
      Meta,
      PrefetchHooks Function()
    >;

class $EnvxSchemaManager {
  final _$EnvxSchema _db;
  $EnvxSchemaManager(this._db);
  $$NotebookTableTableTableManager get notebookTable =>
      $$NotebookTableTableTableManager(_db, _db.notebookTable);
  $$NoteTableTableTableManager get noteTable =>
      $$NoteTableTableTableManager(_db, _db.noteTable);
  $$AttachmentTableTableTableManager get attachmentTable =>
      $$AttachmentTableTableTableManager(_db, _db.attachmentTable);
  $$MetaTableTableTableManager get metaTable =>
      $$MetaTableTableTableManager(_db, _db.metaTable);
}
