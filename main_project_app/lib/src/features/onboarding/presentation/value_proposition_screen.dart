import 'package:flutter/material.dart';

class ValuePropositionScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const ValuePropositionScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'AI summarizes and analyzes your calls in real-time.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Our AI assists in real-time so you never miss important call details.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onGetStarted,
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
