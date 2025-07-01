import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // Add this dependency to pubspec.yaml
import 'api_service.dart';

// Add app theme class or import it from a common file
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

class HandymanRegisterPage extends StatefulWidget {
  const HandymanRegisterPage({Key? key}) : super(key: key);

  @override
  State<HandymanRegisterPage> createState() => _HandymanRegisterPageState();
}

class _HandymanRegisterPageState extends State<HandymanRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final bankNameController = TextEditingController();
  final accountNumberController = TextEditingController();

  final List<String> jobCategories = [
    'Plumber', 'Electrician', 'Carpenter', 'Painter', 'Roofer',
    'Locksmith', 'Cleaner', 'IT Technician', 'Appliance Technician',
    'Tailor', 'Fence & Gate Repair', 'AC Technician', 'Glass Specialist',
  ];

  // Change from single selection to multiple selection
  List<String> selectedExpertise = [];

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

  final List<String> malaysianBanks = [
    'Maybank',
    'CIMB Bank',
    'Public Bank',
    'RHB Bank',
    'Hong Leong Bank',
    'AmBank',
    'Bank Islam Malaysia',
    'Alliance Bank',
    'OCBC Bank',
    'HSBC Bank',
    'Standard Chartered Bank',
    'UOB Bank',
    'Bank Rakyat',
    'Affin Bank',
    'Bank Muamalat',
  ];

  String? selectedState;
  String? selectedCity;
  String? selectedBank;
  bool _isLoading = false;

  List<String> _getCitiesForState() {
    return selectedState != null ? citiesByState[selectedState]! : [];
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if passwords match
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Passwords do not match')),
      );
      return;
    }
    
    // Check required fields
    if (selectedExpertise.isEmpty || selectedState == null || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please fill in all required fields')),
      );
      return;
    }
    
    // Check bank details
    if (selectedBank == null || accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please provide your banking details for payment')),
      );
      return;
    }

    // Generate UUID for the handyman
    final uuid = const Uuid().v4();

    final handymanData = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text.trim(), // Consider hashing before sending
      'state': selectedState,
      'city': selectedCity,
      'expertise': selectedExpertise, // Now sending a list of expertise
      'bankName': selectedBank,
      'accountNumber': accountNumberController.text.trim(),
      'wallet': {
        'balance': 0,
        'pendingWithdrawal': 0
      }
    };

    setState(() => _isLoading = true);

    final api = ApiService();
    final error = await api.registerHandyman(handymanData, uuid);

    setState(() => _isLoading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Registration successful! Your account is pending approval')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(""), // Removed "Handyman Registration" text
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    "Register as a Handyman",
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField("Full Name", nameController),
                  _buildTextField("Phone Number", phoneController,
                      type: TextInputType.phone),
                  
                  // Replace dropdown with expertise checkboxes
                  _buildExpertiseCheckboxes(),
                  
                  // State dropdown that affects city dropdown
                  _buildDropdownField(
                    label: "State",
                    value: selectedState,
                    items: malaysiaStates,
                    onChanged: (val) {
                      setState(() {
                        selectedState = val;
                        // Reset city when state changes
                        selectedCity = null;
                      });
                    },
                    validatorMessage: "Please select a state",
                  ),
                  // City dropdown that's dependent on selected state
                  if (selectedState != null) 
                    _buildDropdownField(
                      label: "City",
                      value: selectedCity,
                      items: _getCitiesForState(),
                      onChanged: (val) => setState(() => selectedCity = val),
                      validatorMessage: "Please select a city",
                    ),
                  _buildTextField("Email", emailController,
                      type: TextInputType.emailAddress),
                  _buildTextField("Password", passwordController,
                      isPassword: true),
                  _buildTextField(
                    "Confirm Password",
                    confirmPasswordController,
                    isPassword: true,
                    icon: Icons.lock_outline, // Changed from lock_check_outlined to lock_outline
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    "Banking Details for Payment",
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "These details will be used for your earnings withdrawal",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textBodyColor),
                  ),
                  const SizedBox(height: 16),
                  // Bank dropdown
                  _buildDropdownField(
                    label: "Bank Name",
                    value: selectedBank,
                    items: malaysianBanks,
                    onChanged: (val) => setState(() => selectedBank = val),
                    validatorMessage: "Please select your bank",
                  ),
                  // Account number field
                  _buildTextField(
                    "Bank Account Number", 
                    accountNumberController,
                    type: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your account number';
                      }
                      if (value.length < 8 || value.length > 20) {
                        return 'Account number should be between 8-20 digits';
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'Account number should contain only digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Register",
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Your account will be reviewed by admins before activation",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textBodyColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New widget for expertise checkboxes
  Widget _buildExpertiseCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Text(
            "Areas of Expertise (Select all that apply)",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textHeadingColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (selectedExpertise.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Please select at least one expertise",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: jobCategories.map((category) {
                  final isSelected = selectedExpertise.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedExpertise.add(category);
                        } else {
                          selectedExpertise.remove(category);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textBodyColor),
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor),
          ),
          suffixIcon: icon != null ? Icon(icon, color: AppTheme.primaryColor) : null,
        ),
        validator: validator ?? (value) =>
            value!.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String validatorMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF9F9F9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor),
          ),
        ),
        validator: (val) => val == null ? validatorMessage : null,
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
      ),
    );
  }
}
