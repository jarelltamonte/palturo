import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopLabeledField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const TopLabeledField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  State<TopLabeledField> createState() => _TopLabeledFieldState();
}

class _TopLabeledFieldState extends State<TopLabeledField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  final FocusNode _focusNode = FocusNode();

  static const double _height = 58;
  static const Duration _duration = Duration(milliseconds: 180);
  static const Curve _curve = Curves.easeOut;

  bool get _isFloating => _focusNode.hasFocus || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_handleChange);
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleChange);
    _controller.removeListener(_handleChange);
    _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double suffixWidth = widget.suffixIcon != null ? 48 : 16;
    final bool floating = _isFloating;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.white,
            width: _focusNode.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Label: centered + large when empty/unfocused,
            // top + small once focused or filled.
            AnimatedPositioned(
              duration: _duration,
              curve: _curve,
              left: 16,
              right: suffixWidth,
              top: floating ? 8 : 0,
              height: floating ? 16 : _height,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedDefaultTextStyle(
                  duration: _duration,
                  curve: _curve,
                  style: TextStyle(
                    color: AppColors.white.withAlpha((0.6 * 255).round()),
                    fontSize: floating ? 12 : 16,
                    fontWeight: floating ? FontWeight.w500 : FontWeight.normal,
                  ),
                  child: Text(widget.label),
                ),
              ),
            ),

            // The actual input, only shown/enabled once floating.
            Positioned(
              left: 16,
              right: suffixWidth,
              bottom: 8,
              height: 22,
              child: AnimatedOpacity(
                duration: _duration,
                curve: _curve,
                opacity: floating ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !floating,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Suffix icon (e.g. show/hide password), always visible.
            if (widget.suffixIcon != null)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(child: widget.suffixIcon!),
              ),
          ],
        ),
      ),
    );
  }
}