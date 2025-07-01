import 'package:flutter/material.dart';
import 'dart:async';
import 'login.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF3F51B5); // Royal Blue
  static const Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
  static const Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
  static const Color textHeadingColor = Color(0xFF2E2E2E); // Dark Slate Gray
  static const Color textBodyColor = Color(0xFF6E6E6E); // Slate Grey
  static const Color successColor = Color(0xFF4CAF50); // Spring Green
  static const Color warningColor = Color(0xFFFF7043); // Coral
  static const Color blueTintBackground = Color(0xFFE3F2FD); // Blue-tint background
  static const Color purpleTintBackground = Color(0xFFF3E5F5); // Purple-tint background
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16), // Reduced padding to allow more space for the image
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval( // Clip to ensure the image stays within circular bounds
                        child: Image.asset(
                          'assets/icon.png',
                          width: 100, // Increased width
                          height: 100, // Increased height
                          fit: BoxFit.cover, // Changed to cover to fill the space
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to an icon if image fails to load
                            return Icon(
                              Icons.handyman_outlined,
                              size: 80,
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                        children: [
                          const TextSpan(
                            text: "Handy",
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: "GO",
                            style: TextStyle(color: AppTheme.secondaryColor),
                          ),
                          const TextSpan(
                            text: " Handyman",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Connecting Experts with Customers",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 1),

            // Bottom Panel
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _animationController.value > 0.6
                      ? (_animationController.value - 0.6) * 2.5
                      : 0,
                  child: child,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Welcome to HandyGO",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Manage jobs, track progress, and connect with customers seamlessly – all in one app.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textBodyColor,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 500),
                              pageBuilder: (_, animation, __) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: const LoginPage(),
                                );
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          "Get Started",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
