import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Repertoires extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class RepertoireMoves extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repertoireId =>
      integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  IntColumn get parentMoveId => integer()
      .nullable()
      .references(RepertoireMoves, #id, onDelete: KeyAction.cascade)();
  TextColumn get fen => text()();
  TextColumn get san => text()();
  TextColumn get label => text().nullable()();
  TextColumn get comment => text().nullable()();
  IntColumn get sortOrder => integer()();
}

class ReviewCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repertoireId =>
      integer().references(Repertoires, #id, onDelete: KeyAction.cascade)();
  IntColumn get leafMoveId =>
      integer().references(RepertoireMoves, #id, onDelete: KeyAction.cascade)();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReviewDate => dateTime()();
  IntColumn get lastQuality => integer().nullable()();
  DateTimeColumn get lastExtraPracticeDate => dateTime().nullable()();
}

@DriftDatabase(tables: [Repertoires, RepertoireMoves, ReviewCards])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_moves_repertoire ON repertoire_moves(repertoire_id)',
          );
          await customStatement(
            'CREATE INDEX idx_moves_parent ON repertoire_moves(parent_move_id)',
          );
          await customStatement(
            'CREATE INDEX idx_moves_fen ON repertoire_moves(repertoire_id, fen)',
          );
          await customStatement(
            'CREATE INDEX idx_cards_due ON review_cards(next_review_date)',
          );
          await customStatement(
            'CREATE INDEX idx_cards_repertoire ON review_cards(repertoire_id)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_cards_leaf ON review_cards(leaf_move_id)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_moves_unique_sibling '
            'ON repertoire_moves(parent_move_id, san) '
            'WHERE parent_move_id IS NOT NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_moves_unique_root '
            'ON repertoire_moves(repertoire_id, san) '
            'WHERE parent_move_id IS NULL',
          );
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chess_trainer.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
