import 'package:drift/drift.dart';

part 'schema.g.dart';

@DataClassName('Notebook')
class NotebookTable extends Table {
  @override
  String get tableName => 'notebook';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Note')
class NoteTable extends Table {
  @override
  String get tableName => 'note';

  TextColumn get id => text()();
  TextColumn get notebookId => text()
      .named('notebook_id')
      .references(NotebookTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get pinned => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Attachment')
class AttachmentTable extends Table {
  @override
  String get tableName => 'attachment';

  TextColumn get id => text()();
  TextColumn get noteId => text()
      .named('note_id')
      .references(NoteTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get sha256 => text().named('sha256')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Meta')
class MetaTable extends Table {
  @override
  String get tableName => 'meta';

  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// drift 数据库定义：两个库（app.db / 将来的 vault.db）共用同一份 schema。
@DriftDatabase(
  tables: [NotebookTable, NoteTable, AttachmentTable, MetaTable],
)
class EnvxSchema extends _$EnvxSchema {
  EnvxSchema(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_notebook_id ON note(notebook_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_updated_at ON note(updated_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notebook_sort ON notebook(sort)',
          );
        },
      );
}
