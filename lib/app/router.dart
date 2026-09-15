import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../features/client_wallet/cards/client_card_access_screen.dart';
import '../features/client_wallet/cards/client_card_details_screen.dart';
import '../features/client_wallet/cards/client_card_referral_screen.dart';
import '../features/client_wallet/cards/client_cards_screen.dart';
import '../features/client_wallet/cards/client_referral_activation_screen.dart';
import '../features/client_wallet/dynamic_qr/client_dynamic_qr_screen.dart';
import '../features/client_wallet/import_card/client_import_card_screen.dart';
import '../features/client_wallet/manual_cards/client_manual_cards_screen.dart';
import '../features/client_wallet/settings/client_settings_screen.dart';
import '../features/client_wallet/wallet/client_recommend_screen.dart';
import '../features/client_wallet/wallet/client_wallet_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: RouteNames.clientWallet,
    routes: [
      GoRoute(
        path: RouteNames.clientWallet,
        builder: (context, state) => const ClientWalletScreen(),
      ),
      GoRoute(
        path: RouteNames.clientCards,
        builder: (context, state) => const ClientCardsScreen(),
      ),
      GoRoute(
        path: RouteNames.clientCardDetails,
        builder: (context, state) => ClientCardDetailsScreen(
          walletCardId: state.pathParameters['walletCardId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardQrAccess,
        builder: (context, state) => ClientCardAccessScreen(
          walletCardId: state.pathParameters['walletCardId']!,
          mode: ClientCardAccessMode.qr,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardNfcAccess,
        builder: (context, state) => ClientCardAccessScreen(
          walletCardId: state.pathParameters['walletCardId']!,
          mode: ClientCardAccessMode.nfc,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardRefer,
        builder: (context, state) => ClientCardReferralScreen(
          walletCardId: state.pathParameters['walletCardId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.clientCardActivate,
        builder: (context, state) => ClientReferralActivationScreen(
          walletCardId: state.pathParameters['walletCardId']!,
        ),
      ),
      GoRoute(
        path: RouteNames.clientImportCard,
        builder: (context, state) => const ClientImportCardScreen(),
      ),
      GoRoute(
        path: RouteNames.clientRecommend,
        builder: (context, state) => const ClientRecommendScreen(),
      ),
      GoRoute(
        path: RouteNames.clientDynamicQr,
        builder: (context, state) => const ClientDynamicQrScreen(),
      ),
      GoRoute(
        path: RouteNames.clientManualCards,
        builder: (context, state) => const ClientManualCardsScreen(),
      ),
      GoRoute(
        path: RouteNames.clientSettings,
        builder: (context, state) => const ClientSettingsScreen(),
      ),
    ],
  );
}
