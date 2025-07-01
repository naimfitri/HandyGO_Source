import 'package:flutter/material.dart';
import 'wallet/WalletPage.dart';
import 'ProfilePage.dart';
import 'HandymanListPage.dart';
import 'location_map_page.dart';
import 'booking status/BookingsPage.dart';
import 'ChatbotPage.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart'; // Add this import

// Define the color scheme constants at the top of your file
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF5C6BC0); // Indigo
  static const Color primaryLight = Color(0xFF8E99F3);
  static const Color primaryDark = Color(0xFF26418F);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A); // Teal
  static const Color secondaryLight = Color(0xFF64D8CB);
  static const Color secondaryDark = Color(0xFF00766C);
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA); // Soft Light Grey
  static const Color surface = Color(0xFFFFFFFF);
  
  // Text Colors
  static const Color textHeading = Color(0xFF333333); // Charcoal Grey
  static const Color textBody = Color(0xFF666666); // Medium Grey
  
  // Status Colors
  static const Color success = Color(0xFF66BB6A); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFEF5350); // Red
  
  // Other UI Colors
  static const Color divider = Color(0xFFEEEEEE);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color shadow = Color(0x1A000000);
}

class HomePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userId;

  const HomePage({
    required this.userName,
    required this.userEmail,
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Add ApiService instance
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCategories = [];
  int _currentIndex = 0;
  late AnimationController _animationController;
  bool _isLoading = false;
  
  // Add state variables to store user data
  String _userName = "";
  String _userEmail = "";
  bool _isLoadingUserData = true;

  final List<Map<String, dynamic>> _categories = [
    {"name": "Plumber", "icon": Icons.plumbing, "color": Colors.blue.shade400},
    {"name": "Electrician", "icon": Icons.electrical_services, "color": Colors.orange.shade400},
    {"name": "Carpenter", "icon": Icons.handyman, "color": Colors.teal.shade400},
    {"name": "Painter", "icon": Icons.format_paint, "color": Colors.purple.shade400},
    {"name": "Roofer", "icon": Icons.home_repair_service, "color": Colors.brown.shade400},
    {"name": "Locksmith", "icon": Icons.lock, "color": Colors.blueGrey.shade400},
    {"name": "Cleaner", "icon": Icons.cleaning_services, "color": Colors.pink.shade400},
    {"name": "IT Technician", "icon": Icons.computer, "color": Colors.amber.shade400},
    {"name": "Appliance Technician", "icon": Icons.kitchen, "color": Colors.deepPurple.shade400},
    {"name": "Tiler", "icon": Icons.grass, "color": Colors.green.shade400},
    {"name": "Fence & Gate Repair", "icon": Icons.fence, "color": Colors.indigo.shade400},
    {"name": "Air-Cond Technician", "icon": Icons.ac_unit, "color": Colors.lightBlue.shade400},
    {"name": "Glass Specialist", "icon": Icons.window, "color": Colors.red.shade400},
  ];

  String _userCity = "";
  String _userCountry = "";
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _filteredCategories = _categories;
    _searchController.addListener(_filterCategories);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchUserData(); // Add this call to fetch user data
    _fetchUserAddress();
  }
  
  // Add method to fetch user data
  Future<void> _fetchUserData() async {
    try {
      // Set default values immediately to avoid showing loading indicators
      setState(() {
        _userName = widget.userName; // Use widget value initially
        _userEmail = widget.userEmail;
      });
      
      final response = await _apiService.getUserData(widget.userId);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (userData != null && userData['name'] != null) {
          setState(() {
            _userName = userData['name'];
            _userEmail = userData['email'] ?? widget.userEmail;
          });
          print('Successfully loaded user data: ${widget.userId}');
        } else {
          print('User data response was empty or missing name field');
        }
      } else {
        print('Failed to load user data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    } finally {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _fetchUserAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final response = await _apiService.getUserAddress(widget.userId);

      if (response.statusCode == 200) {
        final addressData = json.decode(response.body);
        
        setState(() {
          _userCity = addressData['city'] ?? '';
          _userCountry = addressData['country'] ?? '';
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _userCity = "";
          _userCountry = "";
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('Error fetching address: $e');
      setState(() {
        _userCity = "";
        _userCountry = "";
        _isLoadingAddress = false;
      });
    }
  }

  void _filterCategories() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredCategories = _categories;
      } else {
        _filteredCategories = _categories
            .where((category) => category["name"]
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Add a print statement to debug loading state
    print('User data loading state: $_isLoadingUserData, userName: ${widget.userId}');
    
    return Scaffold(
      backgroundColor: AppColors.background, // Changed to light grey background
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          BookingsPage(userId: widget.userId),
          WalletPage(
            userId: widget.userId,
            userName: widget.userName,
            initialWalletBalance: 0.0,
          ),
          ProfilePage(
            userId: widget.userId,
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? _buildChatbotButton(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary, // Changed to primary indigo
            unselectedItemColor: AppColors.textBody,
            showUnselectedLabels: true,
            currentIndex: _currentIndex,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: Icon(_currentIndex == 0 ? Icons.home : Icons.home_outlined),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(_currentIndex == 1 ? Icons.calendar_month : Icons.calendar_month_outlined),
                label: "Bookings",
              ),
              BottomNavigationBarItem(
                icon: Icon(_currentIndex == 2 ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined),
                label: "Wallet",
              ),
              BottomNavigationBarItem(
                icon: Icon(_currentIndex == 3 ? Icons.person : Icons.person_outlined),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatbotButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatbotPage(
              userName: widget.userName,
              userId: widget.userId,
            ),
          ),
        );
      },
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondary,
              AppColors.secondaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 28,
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.success, // Changed to success green
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchUserAddress();
        await _fetchUserData(); // Refresh user data on pull-to-refresh
      },
      color: AppColors.primary, // Changed refresh indicator color
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner at top with location and search
            _buildWelcomeBanner(),
            
            // Search bar (positioned with negative margin for overlap effect)
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSearchBar(),
              ),
            ),
            
            SizedBox(height: 10),
            
            // Grid of service categories with its own header now
            _buildServiceCategories(),
            
            SizedBox(height: 80), // Bottom padding for floating action button
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -50,
          left: -20,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 3;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                        
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Hello, ${_userName.isEmpty ? widget.userName.split(' ')[0] : _userName.split(' ')[0]} 👋",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingAddress
                    ? SizedBox(
                        height: 16,
                        width: 120,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          color: Colors.white.withOpacity(0.5),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withOpacity(0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userCity.isNotEmpty && _userCountry.isNotEmpty
                                ? "$_userCity, $_userCountry"
                                : "Add your location",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
                const Text(
                  "What service do you need today?",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for a service...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: AppColors.textBody),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationMapPage(
                      userName: widget.userName,
                      userEmail: widget.userEmail,
                      userId: widget.userId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.secondary, // Changed to teal secondary color
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Services",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textHeading, // Updated text color for headings
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _filteredCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final category = _filteredCategories[index];
              return _buildServiceCard(
                context,
                category["name"] as String,
                category["icon"] as IconData,
                category["color"] as Color?,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String name, IconData icon, Color? color) {
    // Use our color scheme's primary color if no specific color is provided
    final serviceColor = color ?? AppColors.primary;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HandymanListPage(
              category: name,
              userName: widget.userName,
              userEmail: widget.userEmail,
              userId: widget.userId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: serviceColor.withOpacity(0.15),
              offset: const Offset(0, 7),
              blurRadius: 15,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: serviceColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: serviceColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody, // Updated to body text color
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
