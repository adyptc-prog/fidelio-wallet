import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_settings_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../domain/entities/app_settings.dart';

class FidelioWalletApp extends ConsumerWidget {
  const FidelioWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);

    return settings.when(
      data: (settings) => _RouterApp(settings: settings),
      loading: () => MaterialApp(
        title: 'Fidelio Wallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        title: 'Fidelio Wallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load settings: $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouterApp extends StatefulWidget {
  const _RouterApp({required this.settings});

  final AppSettings settings;

  @override
  State<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<_RouterApp> {
  final _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fidelio Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => _ScaledApp(
        zoomMode: widget.settings.zoomMode,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: _router,
    );
  }
}

class _ScaledApp extends StatelessWidget {
  const _ScaledApp({required this.zoomMode, required this.child});

  final AppZoomMode zoomMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final multiplier = zoomMode == AppZoomMode.large ? 1.16 : 1.0;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: multiplier,
          maxScaleFactor: multiplier,
        ),
      ),
      child: child,
    );
  }
}
