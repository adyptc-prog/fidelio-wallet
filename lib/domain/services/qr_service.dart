import '../entities/subscription_import_payload.dart';
import '../entities/wallet_card.dart';
import '../value_objects/qr_challenge_payload.dart';

abstract interface class QrService {
  SubscriptionImportPayload decodeSubscriptionImportPayload(String rawPayload);

  String encodeSubscriptionImportPayload(SubscriptionImportPayload payload);

  /// Builds a signed referral invite from the referrer's own [sourceCard].
  SubscriptionImportPayload createReferralInvitePayload({
    required WalletCard sourceCard,
  });

  /// Re-derives the same referral payload from an already-imported,
  /// not-yet-activated [referredCard].
  SubscriptionImportPayload createReferralActivationPayload({
    required WalletCard referredCard,
  });

  Future<QrChallengePayload> createDynamicChallenge({
    required String walletId,
    required String cardId,
  });

  String encodeDynamicChallenge(QrChallengePayload payload);

  QrChallengePayload decodeDynamicChallenge(String rawPayload);
}
