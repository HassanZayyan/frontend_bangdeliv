import 'package:flutter/material.dart';

class PrivacyMapScreen extends StatelessWidget {
  const PrivacyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kebijakan Privasi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
