import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final List<Widget> children;
  final double scrollSpeed; // pixels per second

  const MarqueeWidget({
    super.key,
    required this.children,
    this.scrollSpeed = 50.0,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPaused && _scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        // Left to Right: decrease offset
        if (currentScroll <= 0) {
          _scrollController.jumpTo(maxScroll);
        } else {
          _scrollController.jumpTo(currentScroll - (widget.scrollSpeed / 20));
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPaused = true),
      onTapUp: (_) => setState(() => _isPaused = false),
      onTapCancel: () => setState(() => _isPaused = false),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(), // Disable user scroll to let marquee control it
        itemCount: widget.children.length * 100, // Infinite-ish scroll effect
        itemBuilder: (context, index) {
          return widget.children[index % widget.children.length];
        },
      ),
    );
  }
}
