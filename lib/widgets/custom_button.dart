import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'neu_box.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutline;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.icon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed();
    }
  }

  void _onTapCancel() {
    if (!widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 56,
        child: NeuBox(
          isPressed: _isPressed,
          borderRadius: 16,
          padding: EdgeInsets.zero,
          color: widget.isOutline ? AppColors.neuBase : (_isPressed ? AppColors.primary.withOpacity(0.9) : AppColors.primary),
          child: Center(
            child: _buildChild(context, widget.isOutline ? AppColors.primary : Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, Color contentColor) {
    if (widget.isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        ),
      );
    }

    Widget label = Text(
      widget.text,
      style: TextStyle(
        color: contentColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 1.1,
      ),
    );

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, color: contentColor, size: 20),
          const SizedBox(width: 8),
          label,
        ],
      );
    }

    return label;
  }
}
