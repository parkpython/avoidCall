import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KeyFeatureIntroductionScreen extends StatelessWidget {
  final PageController pageController;

  const KeyFeatureIntroductionScreen({super.key, required this.pageController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: pageController,
              children: const [
                _FeaturePage(
                  headline: 'Real-time AI Mediation',
                  visual: 'assets/images/ai_mediation.png', // Placeholder
                ),
                _FeaturePage(
                  headline: 'Conveniently like your native phone app',
                  visual: 'assets/images/native_experience.png', // Placeholder
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.go('/keypad');
            },
            child: const Text('Next'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  final String headline;
  final String visual;

  const _FeaturePage({required this.headline, required this.visual});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          headline,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Placeholder for visual
        Container(
          width: 200,
          height: 200,
          color: Colors.grey[300],
          child: Center(
            child: Text(visual),
          ),
        ),
      ],
    );
  }
}
