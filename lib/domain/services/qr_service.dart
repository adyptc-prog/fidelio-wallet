import '../entities/subscription_import_payload.dart';
import '../value_objects/qr_challenge_payload.dart';

abstract interface class QrService {
  SubscriptionImportPayload decodeSubscriptionImportPayload(String rawPayload);

  String encodeSubscriptionImportPayload(SubscriptionImportPayload payload);

  Future<QrChallengePayload> createDynamicChallenge({
    required String walletId,
    required String cardId,
  });

  String encodeDynamicChallenge(QrChallengePayload payload);

  QrChallengePayload decodeDynamicChallenge(String rawPayload);
}
