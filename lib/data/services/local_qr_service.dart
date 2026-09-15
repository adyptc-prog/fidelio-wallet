import 'dart:convert';
import 'dart:math';

import '../../domain/entities/subscription_import_payload.dart';
import '../../domain/entities/wallet_card.dart';
import '../../domain/services/qr_service.dart';
import '../../domain/value_objects/qr_challenge_payload.dart';

class LocalQrService implements QrService {
  const LocalQrService({
    DateTime Function()? clock,
    this.challengeTtl = const Duration(minutes: 2),
  }) : _clock = clock;

  static const subscriptionImportType = 'subscription_card_import';
  static const subscriptionImportVersion = 1;
  static const dynamicChallengeType = 'dynamic_qr_challenge';
  static const dynamicChallengeVersion = 1;
  static const _legacySignatureKey = 'fidelio-local-qr-signing-key-v1';

  final DateTime Function()? _clock;
  final Duration challengeTtl;

  /// Builds a signed referral invite from the referrer's own [sourceCard].
  /// The friend who imports it gets a brand-new card, pre-advanced by one
  /// welcome-bonus step, that the business will register on first visit.
  @override
  SubscriptionImportPayload createReferralInvitePayload({
    required WalletCard sourceCard,
  }) {
    final entriesTotal = sourceCard.entriesTotal;
    final startingRemaining = entriesTotal == null
        ? null
        : (entriesTotal - 1).clamp(0, entriesTotal);
    final payload = SubscriptionImportPayload(
      type: subscriptionImportType,
      version: subscriptionImportVersion,
      businessId: sourceCard.businessId,
      businessName: sourceCard.businessName ?? sourceCard.businessId,
      businessDomain: sourceCard.businessDomain,
      businessSymbol: sourceCard.businessSymbol,
      businessAccentColor: sourceCard.businessAccentColor,
      clientId: '',
      subscriptionId: _newReferralCardId(),
      cardTitle: sourceCard.displayName,
      validFrom: DateTime.now(),
      validUntil:
          sourceCard.validUntil ??
          DateTime.now().add(const Duration(days: 3650)),
      entriesTotal: entriesTotal,
      entriesRemaining: startingRemaining,
      scanValue: sourceCard.scanValue,
      programType: sourceCard.programType,
      challengeWindowDays: sourceCard.challengeWindowDays,
      referrerCardId: sourceCard.cardId,
      referralProgramEnabled: sourceCard.referralEnabled,
      cardType: 'loyalty',
      issuedAt: DateTime.now(),
    );
    return payload.copyWith(signature: _legacySubscriptionSignature(payload));
  }

  /// Re-derives the same referral payload from an already-imported,
  /// not-yet-activated [referredCard], so the friend can show it to the
  /// business without needing the original raw QR text.
  @override
  SubscriptionImportPayload createReferralActivationPayload({
    required WalletCard referredCard,
  }) {
    final payload = SubscriptionImportPayload(
      type: subscriptionImportType,
      version: subscriptionImportVersion,
      businessId: referredCard.businessId,
      businessName: referredCard.businessName ?? referredCard.businessId,
      businessDomain: referredCard.businessDomain,
      businessSymbol: referredCard.businessSymbol,
      businessAccentColor: referredCard.businessAccentColor,
      clientId: '',
      subscriptionId: referredCard.cardId,
      cardTitle: referredCard.displayName,
      validFrom: DateTime.now(),
      validUntil:
          referredCard.validUntil ??
          DateTime.now().add(const Duration(days: 3650)),
      entriesTotal: referredCard.entriesTotal,
      entriesRemaining: referredCard.entriesRemaining,
      scanValue: referredCard.scanValue,
      programType: referredCard.programType,
      challengeWindowDays: referredCard.challengeWindowDays,
      referrerCardId: referredCard.referrerCardId,
      referralProgramEnabled: referredCard.referralEnabled,
      cardType: 'loyalty',
      issuedAt: DateTime.now(),
    );
    return payload.copyWith(signature: _legacySubscriptionSignature(payload));
  }

  String _newReferralCardId() {
    return 'loyalty-referral-${DateTime.now().microsecondsSinceEpoch}-${_createNonce()}';
  }

  @override
  String encodeSubscriptionImportPayload(SubscriptionImportPayload payload) {
    return jsonEncode(payload.toJson());
  }

  @override
  SubscriptionImportPayload decodeSubscriptionImportPayload(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('QR Payload invalid.');
    }

    final payload = SubscriptionImportPayload.fromJson(decoded);
    if (payload.type != subscriptionImportType) {
      throw const FormatException('Type QR invalid.');
    }
    if (payload.version != subscriptionImportVersion) {
      throw const FormatException('Unsupported QR version.');
    }
    if (payload.subscriptionId.trim().isEmpty) {
      throw const FormatException('Missing subscriptionId.');
    }
    if (payload.businessId.trim().isEmpty) {
      throw const FormatException('Missing businessId.');
    }
    if (payload.cardType != 'subscription' && payload.cardType != 'loyalty') {
      throw const FormatException('Type card invalid.');
    }
    if (payload.signature == null || payload.signature!.trim().isEmpty) {
      throw const FormatException('Missing signature.');
    }
    if (!_constantTimeEquals(
      payload.signature!,
      _legacySubscriptionSignature(payload),
    )) {
      throw const FormatException('Invalid signature.');
    }

    return payload;
  }

  @override
  Future<QrChallengePayload> createDynamicChallenge({
    required String walletId,
    required String cardId,
  }) async {
    if (walletId.trim().isEmpty) {
      throw ArgumentError.value(walletId, 'walletId', 'Wallet ID is required.');
    }
    if (cardId.trim().isEmpty) {
      throw ArgumentError.value(cardId, 'cardId', 'Card ID is required.');
    }

    final timestamp = _now();
    final dynamicChallenge = _createNonce();
    final signature = _signDynamicChallenge(
      walletId: walletId,
      cardId: cardId,
      dynamicChallenge: dynamicChallenge,
      timestamp: timestamp,
    );

    return QrChallengePayload(
      type: dynamicChallengeType,
      version: dynamicChallengeVersion,
      walletId: walletId,
      cardId: cardId,
      dynamicChallenge: dynamicChallenge,
      timestamp: timestamp,
      signature: signature,
    );
  }

  @override
  String encodeDynamicChallenge(QrChallengePayload payload) {
    return jsonEncode(payload.toJson());
  }

  @override
  QrChallengePayload decodeDynamicChallenge(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('QR Payload invalid.');
    }

    final payload = QrChallengePayload.fromJson(decoded);
    if (payload.type != dynamicChallengeType) {
      throw const FormatException('Type QR invalid.');
    }
    if (payload.version != dynamicChallengeVersion) {
      throw const FormatException('Unsupported QR version.');
    }
    if (payload.walletId.trim().isEmpty) {
      throw const FormatException('Missing walletId.');
    }
    if (payload.cardId.trim().isEmpty) {
      throw const FormatException('Missing cardId.');
    }
    if (payload.dynamicChallenge.trim().isEmpty) {
      throw const FormatException('Missing dynamicChallenge.');
    }
    if (payload.signature.trim().isEmpty) {
      throw const FormatException('Missing signature.');
    }

    return payload;
  }

  DateTime _now() => (_clock?.call() ?? DateTime.now()).toUtc();

  String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _signDynamicChallenge({
    required String walletId,
    required String cardId,
    required String dynamicChallenge,
    required DateTime timestamp,
  }) {
    final canonicalPayload = [
      walletId,
      cardId,
      dynamicChallenge,
      timestamp.toUtc().toIso8601String(),
    ].join('|');
    return _hmacSha256Hex(_legacySignatureKey, canonicalPayload);
  }

  String _legacySubscriptionSignature(SubscriptionImportPayload payload) {
    final canonicalPayload = [
      payload.type,
      payload.version.toString(),
      payload.businessId,
      payload.businessName,
      payload.businessDomain ?? '',
      payload.businessSymbol ?? '',
      payload.businessAccentColor?.toString() ?? '',
      payload.clientId,
      payload.subscriptionId,
      payload.cardTitle,
      payload.validFrom.toUtc().toIso8601String(),
      payload.validUntil.toUtc().toIso8601String(),
      payload.cardType,
      payload.entriesTotal?.toString() ?? '',
      payload.entriesRemaining?.toString() ?? '',
      payload.scanValue?.toString() ?? '',
      payload.programType ?? '',
      payload.challengeWindowDays?.toString() ?? '',
      payload.referrerCardId ?? '',
      payload.referralProgramEnabled.toString(),
      payload.issuedAt.toUtc().toIso8601String(),
    ].join('|');
    return _hmacSha256Hex(_legacySignatureKey, canonicalPayload);
  }

  String _hmacSha256Hex(String key, String message) {
    const blockSize = 64;
    List<int> keyBytes = utf8.encode(key);
    if (keyBytes.length > blockSize) {
      keyBytes = _sha256(keyBytes);
    }
    final paddedKey = List<int>.filled(blockSize, 0);
    for (var i = 0; i < keyBytes.length; i += 1) {
      paddedKey[i] = keyBytes[i];
    }
    final outerKeyPad = List<int>.filled(blockSize, 0);
    final innerKeyPad = List<int>.filled(blockSize, 0);
    for (var i = 0; i < blockSize; i += 1) {
      outerKeyPad[i] = paddedKey[i] ^ 0x5c;
      innerKeyPad[i] = paddedKey[i] ^ 0x36;
    }
    final innerHash = _sha256([...innerKeyPad, ...utf8.encode(message)]);
    return _hex(_sha256([...outerKeyPad, ...innerHash]));
  }

  List<int> _sha256(List<int> input) {
    const k = [
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final message = [...input, 0x80];
    while (message.length % 64 != 56) {
      message.add(0);
    }
    final bitLength = input.length * 8;
    message.addAll([
      0,
      0,
      0,
      0,
      (bitLength >> 24) & 0xff,
      (bitLength >> 16) & 0xff,
      (bitLength >> 8) & 0xff,
      bitLength & 0xff,
    ]);

    for (var chunk = 0; chunk < message.length; chunk += 64) {
      final w = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i += 1) {
        final j = chunk + i * 4;
        w[i] =
            ((message[j] << 24) |
                (message[j + 1] << 16) |
                (message[j + 2] << 8) |
                message[j + 3]) &
            0xffffffff;
      }
      for (var i = 16; i < 64; i += 1) {
        final s0 =
            (_rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)) &
            0xffffffff;
        final s1 =
            (_rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)) &
            0xffffffff;
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }
      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;
      for (var i = 0; i < 64; i += 1) {
        final s1 = (_rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)) & 0xffffffff;
        final ch = ((e & f) ^ ((~e) & g)) & 0xffffffff;
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
        final s0 = (_rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)) & 0xffffffff;
        final maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xffffffff;
        final temp2 = (s0 + maj) & 0xffffffff;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    final digest = <int>[];
    for (final value in [h0, h1, h2, h3, h4, h5, h6, h7]) {
      digest.addAll([
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ]);
    }
    return digest;
  }

  int _rotr(int value, int shift) =>
      ((value >> shift) | (value << (32 - shift))) & 0xffffffff;

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i += 1) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}
