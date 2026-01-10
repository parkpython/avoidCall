import 'package:flutter/material.dart';
import 'package:main_project_app/src/features/onboarding/presentation/value_proposition_screen.dart';
import 'package:main_project_app/src/features/onboarding/presentation/key_feature_introduction_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: [
          ValuePropositionScreen(
            onGetStarted: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          KeyFeatureIntroductionScreen(pageController: _pageController),
        ],
      ),
    );
  }
}
