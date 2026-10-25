import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      imagePath: 'screen/onboarding_1_illustration.png',
      titlePrefix: 'Your Data.\n',
      titleHighlight: 'Your Control.',
      subtitle:
          'Keep your expenses on your device or sync securely to the cloud — it\'s your choice.',
    ),
    _OnboardingItem(
      imagePath: 'screen/onboarding_2_illus.png',
      titlePrefix: 'Auto-Log from\n',
      titleHighlight: 'Your SMS',
      subtitle:
          'We automatically detect expenses from your bank SMS — you just review and approve.',
    ),
    _OnboardingItem(
      imagePath: 'screen/onboarding_3_illust.png',
      titlePrefix: 'Split Expenses\n',
      titleHighlight: 'with Friends',
      subtitle:
          'Create groups, record shared expenses, see who owes whom, and settle up with one click.',
    ),
  ];

  Future<void> _handleFinish() async {
    await AuthService.instance.completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _handleNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _handleFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Top PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),
                        // 3D Illustration
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.42,
                          child: Center(
                            child: Image.asset(
                              item.imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) {
                                return Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006948).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.savings_rounded,
                                    size: 80,
                                    color: Color(0xFF006948),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),
                        // Title with highlight
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131B2E),
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(text: item.titlePrefix),
                              TextSpan(
                                text: item.titleHighlight,
                                style: const TextStyle(color: Color(0xFF006948)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Subtitle
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6D7A72),
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const Spacer(flex: 1),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isSelected = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF006948) : const Color(0xFFD9DDEB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006948),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _handleNext,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _handleFinish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D7A72),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String imagePath;
  final String titlePrefix;
  final String titleHighlight;
  final String subtitle;

  const _OnboardingItem({
    required this.imagePath,
    required this.titlePrefix,
    required this.titleHighlight,
    required this.subtitle,
  });
}
