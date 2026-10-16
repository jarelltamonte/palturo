import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TopLabeledField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? maxLength;

  const TopLabeledField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
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
    final bgColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.secondary;

    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: Container(
        constraints: const BoxConstraints(minHeight: _height),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.primary : textColor.withValues(alpha: 0.7),
            width: _focusNode.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 28, suffixWidth, 8),
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
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    minLines: 1,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    maxLength: widget.maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    cursorColor: textColor,
                    buildCounter: (
                      context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) => null,
                    style: AppTextStyles.regularText.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
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
            AnimatedPositioned(
              duration: _duration,
              curve: _curve,
              left: 16,
              right: suffixWidth,
              top: floating ? 8 : 0,
              height: floating ? 16 : _height,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: _duration,
                    curve: _curve,
                    style: AppTextStyles.regularText.copyWith(
                      color: textColor.withAlpha((0.6 * 255).round()),
                      fontSize: floating ? 12 : 16,
                      fontWeight:
                          floating ? FontWeight.w500 : FontWeight.normal,
                    ),
                    child: Text(widget.label),
                  ),
                ),
              ),
            ),
            if (widget.suffixIcon != null)
              Positioned(
                right: 4,
                top: 0,
                height: _height,
                child: Center(child: widget.suffixIcon!),
              ),
          ],
        ),
      ),
    );

    if (widget.maxLength == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Text(
            '${_controller.text.length}/${widget.maxLength}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}