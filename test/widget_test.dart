import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fidelio_wallet/app/app.dart';
import 'package:fidelio_wallet/app/providers/app_settings_providers.dart';
import 'package:fidelio_wallet/data/local_db/app_database.dart';

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
}
