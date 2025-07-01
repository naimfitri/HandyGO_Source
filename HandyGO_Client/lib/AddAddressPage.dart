import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Add Maps import
import 'api_service.dart'; // Import the new API service

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

class AddAddressPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? addressToEdit;

  const AddAddressPage({
    required this.userId,
    this.addressToEdit,
    Key? key,
  }) : super(key: key);

  @override
  _AddAddressPageState createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final ApiService _apiService = ApiService(); // Create instance of API service

  late TextEditingController _unitNameController;
  late TextEditingController _buildingNameController;
  late TextEditingController _streetNameController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  double _latitude = 0.0;
  double _longitude = 0.0;
  
  // Add map controller
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(3.140853, 101.693207), // Default to Kuala Lumpur
    zoom: 12.0,
  );

  // Add map type variable
  MapType _currentMapType = MapType.normal;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isDragging = false; // Track dragging state

  // Add animation controller for pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Add a controller for the bottom sheet
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetPosition = 0.25; // Initial position (25% of screen)

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for marker pulse effect
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    // Initialize controllers
    _unitNameController = TextEditingController(text: widget.addressToEdit?['unitName'] ?? '');
    _buildingNameController = TextEditingController(text: widget.addressToEdit?['buildingName'] ?? '');
    _streetNameController = TextEditingController(text: widget.addressToEdit?['streetName'] ?? '');
    _cityController = TextEditingController(text: widget.addressToEdit?['city'] ?? '');
    _postalCodeController = TextEditingController(text: widget.addressToEdit?['postalCode'] ?? '');
    _countryController = TextEditingController(text: widget.addressToEdit?['country'] ?? '');
    _latitude = widget.addressToEdit?['latitude'] ?? 0.0;
    _longitude = widget.addressToEdit?['longitude'] ?? 0.0;
    
    // Initialize marker if we have coordinates
    if (_latitude != 0.0 && _longitude != 0.0) {
      _markers.add(_createDraggableMarker(LatLng(_latitude, _longitude)));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    _unitNameController.dispose();
    _buildingNameController.dispose();
    _streetNameController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions permanently denied, please enable in settings'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _latitude = position.latitude;
      _longitude = position.longitude;
      
      // Update map position
      _updateMapLocation(LatLng(_latitude, _longitude));

      // Get address from coordinates and update form
      await _getAddressFromLatLng(_latitude, _longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
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
  
  // Create a draggable marker with visual indicators
  Marker _createDraggableMarker(LatLng position) {
    return Marker(
      markerId: MarkerId('selected_location'),
      position: position,
      infoWindow: InfoWindow(
        title: 'Selected Location',
        snippet: '👆 Hold and drag to move'
      ),
      draggable: true,
      onDragStart: (_) => setState(() => _isDragging = true),
      onDragEnd: (newPosition) {
        setState(() {
          _isDragging = false;
        });
        _onMarkerDragEnd(newPosition);
      },
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );
  }
  
  // New method to update map location with improved marker
  void _updateMapLocation(LatLng location) {
    setState(() {
      _markers.clear();
      _markers.add(_createDraggableMarker(location));
    });
    
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 16.0,
        ),
      ),
    );
    
    // Add a brief animation to highlight the map was updated
    _pulseController.reset();
    _pulseController.forward();
  }
  
  // New method to get address from coordinates
  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _buildingNameController.text = place.name ?? 
                                        place.thoroughfare ?? 
                                        place.subThoroughfare ?? '';
                                        
          // For unit name, use subLocality instead of premise (which doesn't exist)
          _unitNameController.text = place.subLocality ?? place.street ?? '';
          
          // For street name, combine thoroughfare and subThoroughfare if available
          _streetNameController.text = [
            place.thoroughfare ?? '',
            place.subThoroughfare ?? ''
          ].where((e) => e.isNotEmpty).join(', ');
          
          _postalCodeController.text = place.postalCode ?? '';
          _cityController.text = place.locality ?? place.subAdministrativeArea ?? '';
          _countryController.text = place.country ?? '';
        });
        
        
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  // Handle marker drag end
  void _onMarkerDragEnd(LatLng position) async {
    _latitude = position.latitude;
    _longitude = position.longitude;
    await _getAddressFromLatLng(_latitude, _longitude);
  }

  // Search for location by address
  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      List<Location> locations = await locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng latLng = LatLng(location.latitude, location.longitude);
        
        _latitude = location.latitude;
        _longitude = location.longitude;
        
        _updateMapLocation(latLng);
        await _getAddressFromLatLng(_latitude, _longitude);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location not found'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for location: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  // Toggle map type
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal 
          ? MapType.satellite 
          : _currentMapType == MapType.satellite
              ? MapType.terrain
              : MapType.normal;
    });
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final addressData = {
      'unitName': _unitNameController.text,
      'buildingName': _buildingNameController.text,
      'streetName': _streetNameController.text,
      'city': _cityController.text,
      'postalCode': _postalCodeController.text,
      'country': _countryController.text,
      'latitude': _latitude,
      'longitude': _longitude,
      'userId': widget.userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      var response;

      if (widget.addressToEdit != null) {
        // Check available keys for debugging
        print('Address edit keys: ${widget.addressToEdit!.keys.toString()}');
        
        // Try to find address ID using various possible keys
        String? addressId;
        if (widget.addressToEdit!.containsKey('id')) {
          addressId = widget.addressToEdit!['id'];
        } else if (widget.addressToEdit!.containsKey('address_id')) {
          addressId = widget.addressToEdit!['address_id'];
        } else if (widget.addressToEdit!.containsKey('_id')) {
          addressId = widget.addressToEdit!['_id'];
        }
        
        // Debug the address ID we found
        print('Found addressId: $addressId');
        
        if (addressId == null) {
          throw Exception('Could not find address ID in the address data');
        }
        
        // Update existing address
        response = await _apiService.updateAddress(widget.userId, addressId, addressData);
      } else {
        // Add new address
        response = await _apiService.addAddress(widget.userId, addressData);
      }

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.addressToEdit != null
                ? 'Address updated successfully'
                : 'Address added successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save address: ${response.statusCode}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving address: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.addressToEdit != null ? 'Edit Address' : 'Add New Address',
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: AppColors.textHeading,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textHeading),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // Add search action in AppBar
          IconButton(
            icon: Icon(Icons.search, color: AppColors.primary),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map as background
          GoogleMap(
            initialCameraPosition: _defaultLocation,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            mapType: _currentMapType,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_latitude != 0.0 && _longitude != 0.0) {
                _updateMapLocation(LatLng(_latitude, _longitude));
              }
            },
            onTap: (latLng) {
              setState(() {
                _latitude = latLng.latitude;
                _longitude = latLng.longitude;
              });
              _updateMapLocation(latLng);
              _getAddressFromLatLng(_latitude, _longitude);
            },
          ),
          
          // Floating map controls (top-right)
          Positioned(
            top: 80,
            right: 16,
            child: Column(
              children: [
                // Map type toggle button
                _buildFloatingButton(
                  icon: _currentMapType == MapType.normal
                      ? Icons.map
                      : _currentMapType == MapType.satellite
                          ? Icons.satellite
                          : Icons.terrain,
                  onTap: _toggleMapType,
                  tooltip: 'Change map type',
                ),
                SizedBox(height: 8),
                // My location button
                _buildFloatingButton(
                  icon: Icons.my_location,
                  onTap: _getCurrentLocation,
                  tooltip: 'My location',
                ),
              ],
            ),
          ),
          
          // Dragging indicator
          if (_isDragging)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.35, // Position above the form sheet
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Release to place pin',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          // Floating form
          DraggableScrollableSheet(
            initialChildSize: _sheetPosition,
            minChildSize: 0.1, // Minimum height (header only)
            maxChildSize: 0.9, // Maximum height (nearly full screen)
            controller: _sheetController,
            builder: (context, scrollController) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sheet handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(top: 10, bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Form content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section heading
                              Text(
                                'Address Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 18,
                                  color: AppColors.textHeading,
                                ),
                              ),
                              SizedBox(height: 16),
                              
                              // Form fields
                              _buildTextField(
                                controller: _unitNameController,
                                label: 'Unit/Apt Number',
                                icon: Icons.home,
                                validator: null,
                              ),
                              SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _buildingNameController,
                                label: 'Building Name',
                                icon: Icons.apartment,
                                validator: null,
                              ),
                              SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _streetNameController,
                                label: 'Street Name',
                                icon: Icons.streetview,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a street address';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _cityController,
                                label: 'City',
                                icon: Icons.location_city,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a city';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _postalCodeController,
                                label: 'Postal Code',
                                icon: Icons.markunread_mailbox,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a postal code';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _countryController,
                                label: 'Country',
                                icon: Icons.public,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a country';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 36),
                              
                              // Save button
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveAddress,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors.textBody.withOpacity(0.3),
                                    disabledForegroundColor: Colors.white70,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        widget.addressToEdit != null ? 'Update Address' : 'Save Address',
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                  
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Helper method to build floating buttons
  Widget _buildFloatingButton({required IconData icon, required VoidCallback onTap, required String tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }

  // Show search dialog
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Location'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter location name or address',
            prefixIcon: Icon(Icons.search, color: AppColors.primary),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            _searchPlace(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _searchPlace(_searchController.text);
            },
            child: Text('Search'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to create consistent text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textBody),
        hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textBody.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textBody.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      style: TextStyle(
        color: AppColors.textHeading,
        fontSize: 15,
      ),
      cursorColor: AppColors.primary,
      validator: validator,
    );
  }
}