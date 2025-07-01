import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'api_service.dart';

// Theme colors
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

class ProfileEditPage extends StatefulWidget {
  final String userId;
  final Function onProfileUpdated;

  // Make sure the constructor matches what's being called
  const ProfileEditPage({
    Key? key,
    required this.userId,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final dbRef = FirebaseDatabase.instance.ref().child('handymen');
  bool _isLoading = true; // Start with loading state
  bool _isSaving = false;
  Map<String, dynamic> _profileData = {};
  final ApiService _apiService = ApiService(); // Create an instance of API service
  
  // Add job categories list
  final List<String> jobCategories = [
    'Plumber', 'Electrician', 'Carpenter', 'Painter', 'Roofer',
    'Locksmith', 'Cleaner', 'IT Technician', 'Appliance Technician',
    'Tailor', 'Fence & Gate Repair', 'AC Technician', 'Glass Specialist',
  ];
  
  // Add states list and cities map
  final List<String> malaysiaStates = [
    'Selangor', 'Kuala Lumpur', 'Johor', 'Penang', 'Perak', 'Pahang',
    'Kedah', 'Kelantan', 'Negeri Sembilan', 'Melaka', 'Terengganu',
    'Sabah', 'Sarawak', 'Putrajaya', 'Labuan'
  ];

  // Map of cities for each state
  final Map<String, List<String>> citiesByState = {
    'Kuala Lumpur': ['KLCC', 'Bukit Bintang', 'Cheras', 'Wangsa Maju', 'Mont Kiara', 'Bangsar', 'Sentul'],
    'Selangor': ['Shah Alam', 'Petaling Jaya', 'Subang Jaya', 'Klang', 'Ampang', 'Kajang', 'Rawang'],
    'Johor': ['Johor Bahru', 'Iskandar Puteri', 'Kulai', 'Muar', 'Batu Pahat', 'Kluang', 'Segamat'],
    'Penang': ['Georgetown', 'Bayan Lepas', 'Butterworth', 'Bukit Mertajam', 'Nibong Tebal', 'Balik Pulau'],
    'Perak': ['Ipoh', 'Taiping', 'Teluk Intan', 'Sitiawan', 'Lumut', 'Kampar', 'Batu Gajah'],
    'Pahang': ['Kuantan', 'Bentong', 'Raub', 'Cameron Highlands', 'Temerloh', 'Mentakab', 'Jerantut'],
    'Kedah': ['Alor Setar', 'Sungai Petani', 'Kulim', 'Langkawi', 'Jitra', 'Yan', 'Kuah'],
    'Kelantan': ['Kota Bharu', 'Pasir Mas', 'Tanah Merah', 'Tumpat', 'Kuala Krai', 'Machang', 'Bachok'],
    'Negeri Sembilan': ['Seremban', 'Port Dickson', 'Nilai', 'Bahau', 'Rembau', 'Tampin', 'Kuala Pilah'],
    'Melaka': ['Melaka City', 'Alor Gajah', 'Jasin', 'Ayer Keroh', 'Klebang', 'Masjid Tanah', 'Merlimau'],
    'Terengganu': ['Kuala Terengganu', 'Kemaman', 'Dungun', 'Marang', 'Besut', 'Setiu', 'Hulu Terengganu'],
    'Sabah': ['Kota Kinabalu', 'Sandakan', 'Tawau', 'Lahad Datu', 'Keningau', 'Semporna', 'Kudat'],
    'Sarawak': ['Kuching', 'Miri', 'Sibu', 'Bintulu', 'Limbang', 'Sarikei', 'Kapit'],
    'Putrajaya': ['Precinct 1', 'Precinct 2', 'Precinct 3', 'Precinct 4', 'Precinct 5', 'Precinct 6'],
    'Labuan': ['Victoria', 'Kiansam', 'Rancha-Rancha', 'Layang-Layangan', 'Gersik', 'Sungai Bedaun'],
  };

  // Change jobCategory to selectedCategories list
  List<String> selectedCategories = [];
  
  // Add state and city selection variables
  String? selectedState;
  String? selectedCity;
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _experienceController;
  // Remove skills controller as requested

  @override
  void initState() {
    super.initState();
    // Fetch data directly from API
    _fetchProfileData();
  }

  // New method to fetch profile data
  Future<void> _fetchProfileData() async {
    try {
      // First try to get profile from API service
      final result = await _apiService.getHandymanProfile(widget.userId);
      
      if (result['success'] && result['profile'] != null) {
        setState(() {
          _profileData = result['profile'];
          _initializeFormData();
          _isLoading = false;
        });
      } else {
        // Fallback to FirebaseDatabase if API fails
        final snapshot = await dbRef.child(widget.userId).once();
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data != null) {
          setState(() {
            _profileData = Map<String, dynamic>.from(data);
            _initializeFormData();
            _isLoading = false;
          });
        } else {
          // Handle case where no data is found
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load profile data'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load profile data'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  // New method to initialize form controllers from fetched data
  void _initializeFormData() {
    _nameController = TextEditingController(text: _profileData['name']);
    _phoneController = TextEditingController(text: _profileData['phone']);
    _experienceController = TextEditingController(text: _profileData['experience']);
    
    // Initialize state and city from fetched data
    selectedState = _profileData['state'];
    selectedCity = _profileData['city'];
    
    debugPrint('💡 Loading state: $selectedState, city: $selectedCity');
    
    // Initialize selected categories from expertise primarily
    if (_profileData['expertise'] != null) {
      // Properly handle different types of expertise data
      if (_profileData['expertise'] is List) {
        selectedCategories = List<String>.from(_profileData['expertise']);
      } else if (_profileData['expertise'] is String) {
        selectedCategories = [_profileData['expertise']];
      } else if (_profileData['expertise'] is Map) {
        selectedCategories = (_profileData['expertise'] as Map)
            .values
            .map((e) => e.toString())
            .toList();
      }
    } else if (_profileData['jobCategory'] != null && _profileData['jobCategory'].toString().isNotEmpty) {
      // Fallback to jobCategory if expertise doesn't exist
      selectedCategories = [_profileData['jobCategory'].toString()];
    }
    
    debugPrint('💡 Selected categories loaded: $selectedCategories');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    // Remove skills controller disposal
    super.dispose();
  }

  // Helper method to get cities for the selected state
  List<String> _getCitiesForSelectedState() {
    return selectedState != null ? citiesByState[selectedState] ?? [] : [];
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that at least one job category is selected
    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one job category'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Validate that state and city are selected
    if (selectedState == null || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your state and city'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Create profile data object with state and city instead of address
      final profileData = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'state': selectedState,
        'city': selectedCity,
        'experience': _experienceController.text,
        'expertise': selectedCategories,
        // Remove skills field as requested
      };

      // Initialize API service
      final apiService = ApiService();
      
      // Update profile via API
      final result = await apiService.updateHandymanProfile(widget.userId, profileData);
      
      if (result['success']) {
        // Notify parent of update
        widget.onProfileUpdated();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(result['message']),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Close the page
        Navigator.pop(context);
      } else {
        // Fallback to direct Firebase update if API fails
        await dbRef.child(widget.userId).update(profileData);
        
        // Notify parent of update
        widget.onProfileUpdated();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully (Firebase fallback)'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Close the page
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to update profile: $e')),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while initial data is being fetched
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(''),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          '', // Removed 'Edit Profile' text
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          )
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _isSaving ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              _buildSectionHeader(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                color: AppTheme.blueTintBackground,
              ),
              const SizedBox(height: 16),
              
              // Name
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Replace address with state dropdown
              _buildStateDropdown(),
              const SizedBox(height: 16),
              
              // City dropdown (only enabled if state is selected)
              _buildCityDropdown(),
              const SizedBox(height: 24),
              
              // Professional Information Section
              _buildSectionHeader(
                title: 'Professional Information',
                icon: Icons.work_outline_rounded,
                color: AppTheme.purpleTintBackground,
              ),
              const SizedBox(height: 16),
              
              // Expertise categories with multi-select checkboxes
              _buildJobCategoriesSection(),
              const SizedBox(height: 16),
              
              // Experience
              _buildTextField(
                controller: _experienceController,
                label: 'Experience',
                icon: Icons.timeline_outlined,
                isRequired: true,
                hintText: 'e.g. 5 years',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your experience';
                  }
                  return null;
                },
              ),
              // Remove Skills field section here
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Styled section header
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 20,
              color: title == 'Personal Information' ? AppTheme.primaryColor : AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: title == 'Personal Information' ? AppTheme.primaryColor : AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Styled text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? hintText,
    int? maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppTheme.textBodyColor.withOpacity(0.6),
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.blueTintBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  topRight: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.warningColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.warningColor,
                width: 1.5,
              ),
            ),
          ),
          style: TextStyle(
            color: AppTheme.textHeadingColor,
            fontSize: 15,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }

  // New method to build job categories section with checkboxes
  Widget _buildJobCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Text(
                'Areas of Expertise', // Changed from 'Job Categories'
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedCategories.isEmpty
                  ? AppTheme.warningColor.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Please select at least one category',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: jobCategories.map((category) {
                  final isSelected = selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedCategories.add(category);
                        } else {
                          selectedCategories.remove(category);
                        }
                      });
                    },
                    selectedColor: AppTheme.purpleTintBackground,
                    checkmarkColor: AppTheme.secondaryColor,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade300,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add build method for state dropdown
  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: const [
              Text(
                'State',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedState == null
                  ? AppTheme.warningColor.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueTintBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedState,
                    hint: const Text('Select State'),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    style: TextStyle(
                      color: AppTheme.textHeadingColor,
                      fontSize: 15,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedState = newValue;
                        selectedCity = null; // Reset city when state changes
                      });
                    },
                    items: malaysiaStates
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add build method for city dropdown
  Widget _buildCityDropdown() {
    final cities = _getCitiesForSelectedState();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: const [
              Text(
                'City',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedState != null && selectedCity == null
                  ? AppTheme.warningColor.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueTintBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.location_city_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCity,
                    hint: Text(selectedState == null 
                        ? 'Select State First' 
                        : 'Select City'),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    style: TextStyle(
                      color: AppTheme.textHeadingColor,
                      fontSize: 15,
                    ),
                    onChanged: selectedState == null 
                        ? null 
                        : (String? newValue) {
                            setState(() {
                              selectedCity = newValue;
                            });
                          },
                    items: cities
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}