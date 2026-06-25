import '../../domain/entities/app_settings.dart';
import '../../domain/entities/wallet_card.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> loadSettings();

  Future<String?> loadClientWalletId();

  Future<void> saveClientWalletId(String walletId);

  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode);

  Future<void> saveZoomMode(AppZoomMode mode);

  Future<void> saveDarkMode(bool enabled);
}

abstract interface class WalletRepository {
  Future<List<WalletCard>> listWalletCards(String walletId);

  Future<WalletCard?> getWalletCard(String walletCardId);

  Future<WalletCard?> getWalletCardByCardId({
    required String walletId,
    required String cardId,
  });

  Future<void> saveWalletCard(WalletCard card);

  Future<void> deleteWalletCard(String walletCardId);
}
