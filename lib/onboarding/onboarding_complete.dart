import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';

class OnboardingComplete extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingComplete({super.key, required this.onDone});

  @override
  State<OnboardingComplete> createState() => _OnboardingCompleteState();
}

class _OnboardingCompleteState extends State<OnboardingComplete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final AudioPlayer _player = AudioPlayer();
  Timer? _soundTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _soundTimer = Timer(const Duration(milliseconds: 100), _playSound);
      }
    });
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setSource(AssetSource('sounds/newmatch.wav'));
  }

  Future<void> _playSound() async {
    if (!mounted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/newmatch.wav'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _soundTimer?.cancel();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/lottie_finished.json',
                width: 350,
                controller: _controller,
                onLoaded: (composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
              ),
              Text(
                'You\'re all set!',
                style: AppTextStyles.headingText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Your account setup is complete.\nLet’s get started.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}