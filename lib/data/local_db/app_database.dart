import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDatabase implements QueryExecutorUser {
  AppDatabase([QueryExecutor? executor])
    : _executor = executor ?? _openConnection();

  AppDatabase.memory() : _executor = NativeDatabase.memory();

  final QueryExecutor _executor;
  bool _opened = false;

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  Future<void> open() async {
    if (_opened) return;
    await _executor.ensureOpen(this);
    for (final statement in _schemaStatements) {
      await _executor.runCustom(statement);
    }
    for (final migration in _columnMigrationStatements) {
      if (!await _columnExists(_executor, migration.table, migration.column)) {
        await _executor.runCustom(migration.statement);
      }
    }
    for (final statement in _indexStatements) {
      await _executor.runCustom(statement);
    }
    _opened = true;
  }

  Future<bool> _columnExists(
    QueryExecutor executor,
    String table,
    String column,
  ) async {
    final rows = await executor.runSelect(
      'PRAGMA table_info($table)',
      const [],
    );
    return rows.any((row) => row['name'] == column);
  }

  Future<void> close() async {
    await _executor.close();
    _opened = false;
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    await open();
    await _executor.runCustom('BEGIN IMMEDIATE');
    try {
      final result = await action();
      await _executor.runCustom('COMMIT');
      return result;
    } catch (_) {
      await _executor.runCustom('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> select(
    String statement, [
    List<Object?> args = const [],
  ]) async {
    await open();
    return _executor.runSelect(statement, args);
  }

  Future<int> insert(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runInsert(statement, args);
  }

  Future<int> update(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runUpdate(statement, args);
  }

  Future<int> delete(String statement, [List<Object?> args = const []]) async {
    await open();
    return _executor.runDelete(statement, args);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'fidelio_wallet.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}

const _schemaStatements = [
  '''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS wallet_cards (
  wallet_card_id TEXT PRIMARY KEY,
  wallet_id TEXT NOT NULL,
  business_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  card_type TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  business_name TEXT,
  business_domain TEXT,
  business_symbol TEXT,
  business_accent_color INTEGER,
  entries_total INTEGER,
  entries_remaining INTEGER,
  scan_value INTEGER,
  valid_until INTEGER,
  dynamic_challenge TEXT,
  challenge_timestamp INTEGER,
  challenge_signature TEXT
)
''',
];

const _indexStatements = [
  '''
CREATE INDEX IF NOT EXISTS idx_wallet_cards_wallet_id
ON wallet_cards (wallet_id)
''',
];

class _ColumnMigrationStatement {
  const _ColumnMigrationStatement({
    required this.table,
    required this.column,
    required this.statement,
  });

  final String table;
  final String column;
  final String statement;
}

const _columnMigrationStatements = [
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'program_type',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN program_type TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'challenge_window_days',
    statement:
        'ALTER TABLE wallet_cards ADD COLUMN challenge_window_days INTEGER',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'referral_enabled',
    statement:
        'ALTER TABLE wallet_cards ADD COLUMN referral_enabled INTEGER NOT NULL DEFAULT 0',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'referrer_card_id',
    statement: 'ALTER TABLE wallet_cards ADD COLUMN referrer_card_id TEXT',
  ),
  _ColumnMigrationStatement(
    table: 'wallet_cards',
    column: 'pending_activation',
    statement:
        'ALTER TABLE wallet_cards ADD COLUMN pending_activation INTEGER NOT NULL DEFAULT 0',
  ),
];
