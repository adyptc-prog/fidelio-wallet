abstract final class RouteNames {
  static const clientWallet = '/client/wallet';
  static const clientCards = '/client/cards';
  static const clientCardDetails = '/client/cards/:walletCardId';
  static const clientCardQrAccess = '/client/cards/:walletCardId/qr';
  static const clientCardNfcAccess = '/client/cards/:walletCardId/nfc';
  static const clientCardRefer = '/client/cards/:walletCardId/refer';
  static const clientCardActivate = '/client/cards/:walletCardId/activate';
  static const clientImportCard = '/client/import';
  static const clientRecommend = '/client/recommend';
  static const clientDynamicQr = '/client/dynamic-qr';
  static const clientManualCards = '/client/manual-cards';
  static const clientSettings = '/client/settings';
}
