import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingPage> pages = [
    OnboardingPage(
      title: 'Welcome to IntelIWave',
      description: 'Monitor your heart health in real-time with advanced ECG technology',
      icon: Icons.favorite,
      showLogo: true,
    ),
    OnboardingPage(
      title: 'Real-Time Monitoring',
      description: 'Get instant heart rate readings and ECG analysis from your Bluetooth device',
      icon: Icons.bluetooth,
      showLogo: false,
    ),
    OnboardingPage(
      title: 'Stay Healthy',
      description: 'Track your health history and receive personalized health insights',
      icon: Icons.health_and_safety,
      showLogo: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    await context.read<SettingsProvider>().completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.lightGrey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Navigation Buttons
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentPage == pages.length - 1
                              ? _finishOnboarding
                              : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _currentPage == pages.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Skip Button
                  if (_currentPage < pages.length - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (page.showLogo)
          Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Center(
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        Icon(
          page.icon,
          size: 80,
          color: AppColors.primary,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.darkGrey,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.grey,
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final bool showLogo;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    this.showLogo = false,
  });
}
