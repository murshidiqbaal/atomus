import 'package:flutter/material.dart';
import 'neu_box.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool isPressed;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.width,
    this.height,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return NeuBox(
      width: width,
      height: height,
      isPressed: isPressed,
      borderRadius: 20,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}
