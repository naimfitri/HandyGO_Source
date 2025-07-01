import 'package:flutter/material.dart';
import 'HandymanListPage.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCategories = [];

  final List<Map<String, dynamic>> _categories = [
    {"name": "Plumber", "icon": Icons.plumbing, "color": Colors.orangeAccent},
    {"name": "Electrician", "icon": Icons.electrical_services, "color": Colors.deepPurpleAccent},
    {"name": "Carpenter", "icon": Icons.handyman, "color": Colors.tealAccent},
    {"name": "Painter", "icon": Icons.format_paint, "color": Colors.cyanAccent},
    {"name": "Roofer", "icon": Icons.home_repair_service, "color": Colors.brown},
    {"name": "Locksmith", "icon": Icons.lock, "color": Colors.blueGrey},
    {"name": "Cleaner", "icon": Icons.cleaning_services, "color": Colors.pinkAccent},
    {"name": "IT Technician", "icon": Icons.computer, "color": Colors.amberAccent},
    {"name": "Appliance Technician", "icon": Icons.kitchen, "color": Colors.deepPurple},
    {"name": "Tiller", "icon": Icons.grass, "color": Colors.orange},
    {"name": "Fence & Gate Repair", "icon": Icons.fence, "color": Colors.purple},
    {"name": "Air Conditioner Technician", "icon": Icons.ac_unit, "color": Colors.lightBlue},
    {"name": "Glass Specialist", "icon": Icons.window, "color": Colors.redAccent},
  ];

  @override
  void initState() {
    super.initState();
    _filteredCategories = _categories;
    _searchController.addListener(_filterCategories);
  }

  void _filterCategories() {
    setState(() {
      _filteredCategories = _categories
          .where((category) => category["name"]
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFB3E5FC), // Light blue background color
      appBar: AppBar(
        title: const Text("Categories", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search for a category...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: _filteredCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final category = _filteredCategories[index];
                  return _buildCategoryCard(
                    context,
                    category["name"] as String,
                    category["icon"] as IconData,
                    category["color"] as Color?,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String name, IconData icon, Color? color) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HandymanListPage(
              category: name, userName: '', userEmail: '', userId: '',
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: color?.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
