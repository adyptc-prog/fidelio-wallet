import 'package:flutter/material.dart';

import '../../../presentation/layouts/section_shell.dart';

class ClientManualCardsScreen extends StatelessWidget {
  const ClientManualCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionShell(
      title: 'Manual Cards',
      child: Center(
        child: Text(
          'Manual card entry will be available in a future update.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
