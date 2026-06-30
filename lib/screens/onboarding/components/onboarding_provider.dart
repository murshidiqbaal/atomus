import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../main_layout.dart';

class OnboardingProvider extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentPage = 0;
  bool _notificationScreenVisible = false;

  int get currentPage => _currentPage;
  bool get isLastPage => _currentPage == 3;
  bool get notificationScreenVisible => _notificationScreenVisible;

  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void nextPage() {
    if (_currentPage < 3) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      showNotificationPermissionScreen();
    }
  }

  void previousPage() {
    if (_currentPage > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void skipOnboarding() {
    showNotificationPermissionScreen();
  }

  void showNotificationPermissionScreen() {
    _notificationScreenVisible = true;
    notifyListeners();
  }

  Future<void> requestNotificationPermission(BuildContext context) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
    if (context.mounted) {
      completeOnboarding(context);
    }
  }

  void completeOnboarding(BuildContext context) {
    final settingsBox = Hive.box('settings');
    settingsBox.put('onboarding_completed', true);
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const MainLayout(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
