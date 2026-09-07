import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palturo/models/onboarding_item.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/landing_page.dart';


class OnboardingIntro extends StatefulWidget {
  const OnboardingIntro({super.key});

  @override
  State<OnboardingIntro> createState() => _OnboardingIntroState();
}

class _OnboardingIntroState extends State<OnboardingIntro> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<OnboardItem> _pages = [
    const OnboardItem(
      svg: 'assets/icons/icon_o1.svg',
      title: 'AI-Powered\nReciprocal Matching',
      description:
          'Get matched with learners and mentors\nwho are actually a fit for you, not just the\nclosest available.',
      lottieUrl: 'assets/lottie/lottie_1.json',
    ),
    const OnboardItem(
      svg: 'assets/icons/icon_o2.svg',
      title: 'Dual Learner-\nMentor Roles',
      description:
          'Learn, teach, or both.\nTeach what you know, learn what you don\'t.',
      lottieUrl: 'assets/lottie/lottie_2.json',
    ),
    const OnboardItem(
      svg: 'assets/icons/icon_o3.svg',
      title: 'Exchange Skills,\nSkip the Fees',
      description:
          'Trade knowledge, not money.\nBuild skills through community, not\nsubscriptions.',
      lottieUrl: 'assets/lottie/lottie_3.json',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Column(
          spacing: 20,
          children: [
            Flexible(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged:
                    (value) => setState(() {
                      _currentPage = value;
                    }),
                itemBuilder: (context, index) {
                  return _OnboardItemView(item: _pages[index]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: List.generate(_pages.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: _currentPage == index ? 18 : 8,
                  decoration: BoxDecoration(
                    color:
                        _currentPage == index
                            ? AppColors.primary 
                            : AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  textStyle: AppTextStyles.boldText,
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardItemView extends StatelessWidget {
  const _OnboardItemView({required this.item});

  final OnboardItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        SvgPicture.asset(item.svg, width: 40),
        Expanded(child: Lottie.asset(item.lottieUrl)),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.description,
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
