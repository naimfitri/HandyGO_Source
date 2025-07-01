import 'package:flutter/material.dart';
import 'HandymanHomePage.dart';
import 'BookingPage.dart';
import 'ProfilePage.dart';
import 'common_widgets.dart'; // Make sure to import this

class MainNavigationContainer extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const MainNavigationContainer({
    Key? key, 
    required this.userId,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  late int _currentIndex;
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    debugPrint('MainNavigationContainer initialized with index: ${widget.initialIndex}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    debugPrint('Navigation tab tapped: $index');
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          // If not on the first tab, go to the first tab
          setState(() {
            _currentIndex = 0;
            _pageController.jumpToPage(0);
          });
          return false;
        }
        return true; // Allow app to exit
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Prevent swiping
          children: [
            HandymanHomePage(userId: widget.userId),
            BookingPage(userId: widget.userId),
            ProfilePage(userId: widget.userId),
          ],
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        // Use the HandymanBottomNavBar from common_widgets.dart
        bottomNavigationBar: HandymanBottomNavBar(
          currentIndex: _currentIndex,
          userId: widget.userId,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}