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
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
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
  int get schemaVersion => 2;

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
          await _createReviewCardIndexes();
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
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Rebuild the table so the physical DEFAULT changes from 1 to 0.
            await m.alterTable(TableMigration(reviewCards));

            // Recreate review_cards indexes dropped during the table rebuild.
            await _createReviewCardIndexes();

            // Backfill: set interval_days = 0 on fresh cards that got the old
            // default. Use last_quality IS NULL to distinguish truly fresh cards
            // from failed-reviewed cards (SM-2 fail also sets repetitions=0,
            // interval=1, but always writes a non-null lastQuality value).
            await customStatement(
              'UPDATE review_cards SET interval_days = 0 '
              'WHERE repetitions = 0 AND interval_days = 1 '
              'AND last_quality IS NULL',
            );
          }
        },
      );

  /// Creates the indexes on the review_cards table. Called from both
  /// [onCreate] (fresh install) and [onUpgrade] (after alterTable rebuild).
  Future<void> _createReviewCardIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cards_due ON review_cards(next_review_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cards_repertoire ON review_cards(repertoire_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_cards_leaf ON review_cards(leaf_move_id)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chess_trainer.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
