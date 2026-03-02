import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:chess_trainer/repositories/local/database.dart';

// ---------------------------------------------------------------------------
// v1 CREATE TABLE statements (matching the original onCreate with DEFAULT 1)
// ---------------------------------------------------------------------------

const _v1CreateRepertoires = '''
  CREATE TABLE repertoires (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''';

const _v1CreateRepertoireMoves = '''
  CREATE TABLE repertoire_moves (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    repertoire_id INTEGER NOT NULL REFERENCES repertoires (id) ON DELETE CASCADE,
    parent_move_id INTEGER REFERENCES repertoire_moves (id) ON DELETE CASCADE,
    fen TEXT NOT NULL,
    san TEXT NOT NULL,
    label TEXT,
    comment TEXT,
    sort_order INTEGER NOT NULL
  )
''';

const _v1CreateReviewCards = '''
  CREATE TABLE review_cards (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    repertoire_id INTEGER NOT NULL REFERENCES repertoires (id) ON DELETE CASCADE,
    leaf_move_id INTEGER NOT NULL REFERENCES repertoire_moves (id) ON DELETE CASCADE,
    ease_factor REAL NOT NULL DEFAULT 2.5,
    interval_days INTEGER NOT NULL DEFAULT 1,
    repetitions INTEGER NOT NULL DEFAULT 0,
    next_review_date INTEGER NOT NULL,
    last_quality INTEGER,
    last_extra_practice_date INTEGER
  )
''';

// v1 indexes (matching the original onCreate)
const _v1Indexes = [
  'CREATE INDEX idx_moves_repertoire ON repertoire_moves(repertoire_id)',
  'CREATE INDEX idx_moves_parent ON repertoire_moves(parent_move_id)',
  'CREATE INDEX idx_moves_fen ON repertoire_moves(repertoire_id, fen)',
  'CREATE INDEX idx_cards_due ON review_cards(next_review_date)',
  'CREATE INDEX idx_cards_repertoire ON review_cards(repertoire_id)',
  'CREATE UNIQUE INDEX idx_cards_leaf ON review_cards(leaf_move_id)',
  'CREATE UNIQUE INDEX idx_moves_unique_sibling '
      'ON repertoire_moves(parent_move_id, san) '
      'WHERE parent_move_id IS NOT NULL',
  'CREATE UNIQUE INDEX idx_moves_unique_root '
      'ON repertoire_moves(repertoire_id, san) '
      'WHERE parent_move_id IS NULL',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory database pre-populated with the v1 schema and optional
/// seed data, then wraps it in [AppDatabase] so the v1 -> v2 migration runs.
AppDatabase createV1DatabaseAndMigrate({
  void Function(raw.Database db)? seedData,
}) {
  return AppDatabase(NativeDatabase.memory(
    setup: (db) {
      // Create the v1 tables.
      db.execute(_v1CreateRepertoires);
      db.execute(_v1CreateRepertoireMoves);
      db.execute(_v1CreateReviewCards);
      for (final idx in _v1Indexes) {
        db.execute(idx);
      }

      // Seed data before migration.
      seedData?.call(db);

      // Tell Drift this is a v1 database so it runs onUpgrade.
      db.execute('PRAGMA user_version = 1');
    },
  ));
}

/// Encodes a [DateTime] as seconds-since-epoch, matching Drift's default
/// date-time encoding for non-text mode.
int _encodeDateTime(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('v1 -> v2 migration', () {
    test('backfills fresh cards to interval_days = 0', () async {
      final reviewDate = _encodeDateTime(DateTime(2026, 1, 1));

      final db = createV1DatabaseAndMigrate(
        seedData: (rawDb) {
          // Repertoire
          rawDb.execute("INSERT INTO repertoires (name) VALUES ('Test')");
          // Move (used as leaf)
          rawDb.execute(
            'INSERT INTO repertoire_moves '
            '(repertoire_id, parent_move_id, fen, san, sort_order) '
            "VALUES (1, NULL, 'fen1', 'e4', 0)",
          );
          rawDb.execute(
            'INSERT INTO repertoire_moves '
            '(repertoire_id, parent_move_id, fen, san, sort_order) '
            "VALUES (1, 1, 'fen2', 'e5', 0)",
          );
          rawDb.execute(
            'INSERT INTO repertoire_moves '
            '(repertoire_id, parent_move_id, fen, san, sort_order) '
            "VALUES (1, 2, 'fen3', 'Nf3', 0)",
          );

          // Card 1: fresh card (should be migrated to interval_days = 0)
          rawDb.execute(
            'INSERT INTO review_cards '
            '(repertoire_id, leaf_move_id, ease_factor, interval_days, '
            'repetitions, next_review_date, last_quality) '
            'VALUES (1, 1, 2.5, 1, 0, $reviewDate, NULL)',
          );

          // Card 2: failed-reviewed card (should NOT be migrated)
          rawDb.execute(
            'INSERT INTO review_cards '
            '(repertoire_id, leaf_move_id, ease_factor, interval_days, '
            'repetitions, next_review_date, last_quality) '
            'VALUES (1, 2, 2.5, 1, 0, $reviewDate, 1)',
          );

          // Card 3: reviewed card (should NOT be migrated)
          rawDb.execute(
            'INSERT INTO review_cards '
            '(repertoire_id, leaf_move_id, ease_factor, interval_days, '
            'repetitions, next_review_date, last_quality) '
            'VALUES (1, 3, 2.5, 7, 3, $reviewDate, 5)',
          );
        },
      );

      // Trigger migration by reading from the database.
      final cards = await (db.select(db.reviewCards)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      expect(cards, hasLength(3));

      // Fresh card: interval_days migrated from 1 to 0.
      expect(cards[0].intervalDays, 0);
      expect(cards[0].repetitions, 0);
      expect(cards[0].lastQuality, isNull);

      // Failed-reviewed card: interval_days unchanged.
      expect(cards[1].intervalDays, 1);
      expect(cards[1].repetitions, 0);
      expect(cards[1].lastQuality, 1);

      // Reviewed card: interval_days unchanged.
      expect(cards[2].intervalDays, 7);
      expect(cards[2].repetitions, 3);
      expect(cards[2].lastQuality, 5);

      await db.close();
    });

    test('new cards inserted after migration get interval_days = 0', () async {
      final db = createV1DatabaseAndMigrate(
        seedData: (rawDb) {
          rawDb.execute("INSERT INTO repertoires (name) VALUES ('Test')");
          rawDb.execute(
            'INSERT INTO repertoire_moves '
            '(repertoire_id, parent_move_id, fen, san, sort_order) '
            "VALUES (1, NULL, 'fen1', 'e4', 0)",
          );
        },
      );

      // Trigger migration by performing a read.
      await db.select(db.reviewCards).get();

      // Insert a new card using ReviewCardsCompanion.insert (omitting
      // intervalDays so the physical DEFAULT is used).
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: 1,
              leafMoveId: 1,
              nextReviewDate: DateTime(2026, 6, 1),
            ),
          );

      final cards = await db.select(db.reviewCards).get();
      expect(cards, hasLength(1));
      expect(cards.first.intervalDays, 0);

      await db.close();
    });

    test('review_cards indexes exist after migration', () async {
      final db = createV1DatabaseAndMigrate(
        seedData: (rawDb) {
          rawDb.execute("INSERT INTO repertoires (name) VALUES ('Test')");
          rawDb.execute(
            'INSERT INTO repertoire_moves '
            '(repertoire_id, parent_move_id, fen, san, sort_order) '
            "VALUES (1, NULL, 'fen1', 'e4', 0)",
          );
        },
      );

      // Trigger migration.
      await db.select(db.reviewCards).get();

      // Query sqlite_master for indexes on review_cards.
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'index' AND tbl_name = 'review_cards' "
        "ORDER BY name",
      ).get();

      final indexNames = result.map((r) => r.read<String>('name')).toList();

      expect(indexNames, contains('idx_cards_due'));
      expect(indexNames, contains('idx_cards_repertoire'));
      expect(indexNames, contains('idx_cards_leaf'));

      await db.close();
    });

    test('fresh install (v2) creates correct default', () async {
      // A plain AppDatabase with no v1 setup — exercises onCreate path.
      final db = AppDatabase(NativeDatabase.memory());

      // Seed required parent rows.
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );
      await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: 1,
              fen: 'fen1',
              san: 'e4',
              sortOrder: 0,
            ),
          );

      // Insert a card relying on the DB default for intervalDays.
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: 1,
              leafMoveId: 1,
              nextReviewDate: DateTime(2026, 6, 1),
            ),
          );

      final cards = await db.select(db.reviewCards).get();
      expect(cards, hasLength(1));
      expect(cards.first.intervalDays, 0);

      await db.close();
    });
  });
}
