import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fidelio_wallet/app/app.dart';
import 'package:fidelio_wallet/app/providers/app_settings_providers.dart';
import 'package:fidelio_wallet/app/providers/client_wallet_providers.dart';
import 'package:fidelio_wallet/core/constants/app_constants.dart';
import 'package:fidelio_wallet/data/local_db/app_database.dart';
import 'package:fidelio_wallet/data/repositories/drift_repositories.dart';
import 'package:fidelio_wallet/domain/entities/wallet_card.dart';
import 'package:fidelio_wallet/domain/value_objects/card_status.dart';

const _testWalletId = 'wallet-test';

void main() {
  testWidgets('wallet home shows My Cards and Import Card', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FidelioWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Cards'), findsOneWidget);
    expect(find.text('Import Card'), findsOneWidget);
  });

  testWidgets('navigates to cards screen on My Cards tap', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FidelioWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cards'));
    await tester.pumpAndSettle();

    expect(find.text('My Cards'), findsWidgets);
    expect(
      find.text(
        'There are no cards in the wallet. Import a card received from a business.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings screen shows card view zoom and dark mode', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FidelioWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Card View'), findsOneWidget);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Wallet ID'), findsOneWidget);
  });

  testWidgets('wallet home shows a full-width Recommend Fidelio button', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FidelioWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommend Fidelio'), findsOneWidget);
  });

  testWidgets('client can open and edit the Fidelio recommendation message', (
    tester,
  ) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FidelioWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recommend Fidelio'));
    await tester.pumpAndSettle();

    expect(find.text('Recommend Fidelio'), findsWidgets);
    expect(find.text(AppConstants.recommendationText), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Copy Text'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A custom message.');
    await tester.pump();

    expect(find.text('A custom message.'), findsOneWidget);
    expect(find.text(AppConstants.recommendationText), findsNothing);
  });

  testWidgets(
    'client card details shows Refer a Friend for any active loyalty card',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.memory();
      addTearDown(db.close);

      // referralEnabled is false here on purpose: it only reflects the
      // business's toggle state at the moment this card was imported, and
      // must not hide the button — the business enforces the toggle live,
      // at redemption time, not the client at display time.
      await DriftWalletRepository(db).saveWalletCard(
        WalletCard(
          walletCardId: 'wallet-card-referral',
          walletId: _testWalletId,
          businessId: 'business-1',
          cardId: 'loyalty-1',
          cardType: 'loyalty',
          displayName: 'Coffee Loyalty',
          createdAt: DateTime.utc(2026, 5, 13),
          status: CardStatus.active,
          businessName: 'Coffee Shop',
          entriesTotal: 8,
          entriesRemaining: 5,
          scanValue: 1,
          programType: 'stamps',
          referralEnabled: false,
        ),
      );
      await DriftWalletRepository(db).saveWalletCard(
        WalletCard(
          walletCardId: 'wallet-card-subscription',
          walletId: _testWalletId,
          businessId: 'business-2',
          cardId: 'subscription-2',
          cardType: 'subscription',
          displayName: 'Bakery Membership',
          createdAt: DateTime.utc(2026, 5, 13),
          status: CardStatus.active,
          businessName: 'Bakery',
          entriesTotal: 8,
          entriesRemaining: 5,
          scanValue: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            clientWalletIdProvider.overrideWith((ref) async => _testWalletId),
          ],
          child: const FidelioWalletApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Cards'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee Loyalty'));
      await tester.pumpAndSettle();
      expect(find.text('Refer a Friend'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bakery Membership'));
      await tester.pumpAndSettle();
      expect(find.text('Refer a Friend'), findsNothing);
    },
  );
}
