import '../../domain/entities/app_settings.dart';
import '../../domain/entities/wallet_card.dart';
import '../../domain/value_objects/card_status.dart';
import '../local_db/app_database.dart';
import 'repository_interfaces.dart';

class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._db);

  static const _clientCardsViewModeKey = 'client_cards_view_mode';
  static const _zoomModeKey = 'zoom_mode';
  static const _darkModeKey = 'dark_mode';
  static const _clientWalletIdKey = 'client_wallet_id';

  final AppDatabase _db;

  @override
  Future<AppSettings> loadSettings() async {
    final rows = await _db.select('SELECT key, value FROM app_settings');
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String?,
    };
    return AppSettings(
      clientCardsViewMode: _clientCardsViewMode(
        values[_clientCardsViewModeKey],
      ),
      zoomMode: _zoomMode(values[_zoomModeKey]),
      darkMode: values[_darkModeKey] == 'true',
    );
  }

  @override
  Future<String?> loadClientWalletId() async {
    final rows = await _db.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      [_clientWalletIdKey],
    );
    final value = rows.isEmpty ? null : rows.first['value'] as String?;
    return value == null || value.trim().isEmpty ? null : value;
  }

  @override
  Future<void> saveClientWalletId(String walletId) =>
      _saveSetting(_clientWalletIdKey, walletId);

  @override
  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode) =>
      _saveSetting(_clientCardsViewModeKey, mode.name);

  @override
  Future<void> saveZoomMode(AppZoomMode mode) =>
      _saveSetting(_zoomModeKey, mode.name);

  @override
  Future<void> saveDarkMode(bool enabled) =>
      _saveSetting(_darkModeKey, enabled.toString());

  Future<void> _saveSetting(String key, String value) {
    return _db.insert(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  ClientCardsViewMode _clientCardsViewMode(String? value) {
    return ClientCardsViewMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ClientCardsViewMode.list,
    );
  }

  AppZoomMode _zoomMode(String? value) {
    return AppZoomMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppZoomMode.normal,
    );
  }
}

class DriftWalletRepository implements WalletRepository {
  const DriftWalletRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<WalletCard>> listWalletCards(String walletId) async {
    final rows = await _db.select(
      'SELECT * FROM wallet_cards WHERE wallet_id = ? ORDER BY created_at ASC',
      [walletId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<WalletCard?> getWalletCard(String walletCardId) async {
    final rows = await _db.select(
      'SELECT * FROM wallet_cards WHERE wallet_card_id = ? LIMIT 1',
      [walletCardId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<WalletCard?> getWalletCardByCardId({
    required String walletId,
    required String cardId,
  }) async {
    final rows = await _db.select(
      'SELECT * FROM wallet_cards WHERE wallet_id = ? AND card_id = ? LIMIT 1',
      [walletId, cardId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> saveWalletCard(WalletCard card) async {
    await _db.insert(
      '''
INSERT OR REPLACE INTO wallet_cards
(wallet_card_id, wallet_id, business_id, card_id, card_type, display_name,
 created_at, status, business_name, business_domain, business_symbol,
 business_accent_color, entries_total, entries_remaining, valid_until,
 scan_value, dynamic_challenge, challenge_timestamp, challenge_signature,
 program_type, challenge_window_days, referral_enabled, referrer_card_id,
 pending_activation)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        card.walletCardId,
        card.walletId,
        card.businessId,
        card.cardId,
        card.cardType,
        card.displayName,
        _date(card.createdAt),
        card.status.name,
        card.businessName,
        card.businessDomain,
        card.businessSymbol,
        card.businessAccentColor,
        card.entriesTotal,
        card.entriesRemaining,
        _nullableDate(card.validUntil),
        card.scanValue,
        card.dynamicChallenge,
        _nullableDate(card.challengeTimestamp),
        card.challengeSignature,
        card.programType,
        card.challengeWindowDays,
        _bool(card.referralEnabled),
        card.referrerCardId,
        _bool(card.pendingActivation),
      ],
    );
  }

  @override
  Future<void> deleteWalletCard(String walletCardId) async {
    await _db.delete('DELETE FROM wallet_cards WHERE wallet_card_id = ?', [
      walletCardId,
    ]);
  }

  WalletCard _fromRow(Map<String, Object?> row) {
    return WalletCard(
      walletCardId: row['wallet_card_id']! as String,
      walletId: row['wallet_id']! as String,
      businessId: row['business_id']! as String,
      cardId: row['card_id']! as String,
      cardType: row['card_type']! as String,
      displayName: row['display_name']! as String,
      createdAt: _readDate(row['created_at']),
      status: _status(row['status']),
      businessName: row['business_name'] as String?,
      businessDomain: row['business_domain'] as String?,
      businessSymbol: row['business_symbol'] as String?,
      businessAccentColor: row['business_accent_color'] as int?,
      entriesTotal: row['entries_total'] as int?,
      entriesRemaining: row['entries_remaining'] as int?,
      scanValue: row['scan_value'] as int?,
      validUntil: _readNullableDate(row['valid_until']),
      dynamicChallenge: row['dynamic_challenge'] as String?,
      challengeTimestamp: _readNullableDate(row['challenge_timestamp']),
      challengeSignature: row['challenge_signature'] as String?,
      programType: row['program_type'] as String?,
      challengeWindowDays: row['challenge_window_days'] as int?,
      referralEnabled: _readBool(row['referral_enabled']),
      referrerCardId: row['referrer_card_id'] as String?,
      pendingActivation: _readBool(row['pending_activation']),
    );
  }
}

int _date(DateTime value) => value.toUtc().millisecondsSinceEpoch;
int? _nullableDate(DateTime? value) => value == null ? null : _date(value);
int _bool(bool value) => value ? 1 : 0;
bool _readBool(Object? value) => (value as int? ?? 0) != 0;
DateTime _readDate(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value! as int, isUtc: true);
DateTime? _readNullableDate(Object? value) =>
    value == null ? null : _readDate(value);

CardStatus _status(Object? value) {
  return CardStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => CardStatus.draft,
  );
}
