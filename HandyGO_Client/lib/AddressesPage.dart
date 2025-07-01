import 'package:flutter/material.dart';
import 'dart:convert';
import 'AddAddressPage.dart';
import 'api_service.dart'; // Import API service

// Define the color scheme constants
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF5C6BC0); // Indigo
  static const Color primaryLight = Color(0xFF8E99F3);
  static const Color primaryDark = Color(0xFF26418F);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A); // Teal
  static const Color amber = Color(0xFFFFB74D); // Amber
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA); // Soft Light Grey
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  
  // Text Colors
  static const Color textHeading = Color(0xFF333333); // Charcoal Grey
  static const Color textBody = Color(0xFF666666); // Medium Grey
  
  // Status Colors
  static const Color success = Color(0xFF66BB6A); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFEF5350); // Red
}

class AddressesPage extends StatefulWidget {
  final String userId;

  const AddressesPage({required this.userId, Key? key}) : super(key: key);

  @override
  _AddressesPageState createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final ApiService _apiService = ApiService(); // Create instance of API service
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _primaryAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = [
      address['unitName'],
      address['buildingName'],
      address['streetName'],
      address['city'],
      address['postalCode'],
      address['country'],
    ];

    return parts.where((part) => part != null && part.toString().isNotEmpty)
        .join(', ');
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getUserData(widget.userId);

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        
        List<Map<String, dynamic>> addresses = [];
        
        // Get primary address
        if (userData['primaryAddress'] != null) {
          setState(() {
            _primaryAddress = Map<String, dynamic>.from(userData['primaryAddress']);
          });
        }
        
        // Get all locations
        if (userData['locations'] != null) {
          final locations = Map<String, dynamic>.from(userData['locations']);
          
          locations.forEach((id, value) {
            final address = Map<String, dynamic>.from(value as Map);
            address['id'] = id;
            addresses.add(address);
          });
        }
        
        setState(() {
          _addresses = addresses;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading addresses: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setPrimaryAddress(Map<String, dynamic> address) async {
    try {
      final response = await _apiService.setPrimaryAddress(
        widget.userId, 
        address['id']
      );

      if (response.statusCode == 200) {
        setState(() {
          _primaryAddress = address;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Primary address updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update primary address: ${response.statusCode}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating primary address: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final response = await _apiService.deleteAddress(widget.userId, addressId);

      if (response.statusCode == 200) {
        _loadAddresses(); // Reload addresses
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete address: ${response.statusCode}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting address: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Addresses',
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: AppColors.textHeading,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textHeading),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 80,
                        color: AppColors.textBody.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No addresses found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeading,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add your first address',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 28),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddAddressPage(userId: widget.userId),
                            ),
                          ).then((_) => _loadAddresses());
                        },
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add New Address'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Text(
                            "Your saved addresses",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeading,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddAddressPage(userId: widget.userId),
                                ),
                              ).then((_) => _loadAddresses());
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add New'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._addresses.map((address) {
                      final isPrimary = _primaryAddress != null && 
                        _primaryAddress!['id'] == address['id'];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isPrimary 
                            ? BorderSide(color: AppColors.primary, width: 2)
                            : BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _formatAddress(address),
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                        color: AppColors.textHeading,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (isPrimary)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Primary',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _setPrimaryAddress(address),
                                      child: Text('Set as Primary'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddAddressPage(
                                              userId: widget.userId,
                                              addressToEdit: address,
                                            ),
                                          ),
                                        ).then((_) => _loadAddresses());
                                      },
                                      padding: EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              'Delete Address',
                                              style: TextStyle(
                                                color: AppColors.textHeading,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this address?',
                                              style: TextStyle(
                                                color: AppColors.textBody,
                                              ),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: AppColors.textBody,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteAddress(address['id']);
                                                },
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: AppColors.error,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      padding: EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
      floatingActionButton: _addresses.isNotEmpty ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddAddressPage(userId: widget.userId),
            ),
          ).then((_) => _loadAddresses());
        },
        backgroundColor: AppColors.secondary,
        child: const Icon(Icons.add_location_alt),
        elevation: 2,
      ) : null,
    );
  }
}