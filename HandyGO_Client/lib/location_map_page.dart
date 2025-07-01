import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert' as convert;
import 'api_service.dart';

class LocationMapPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userId;

  const LocationMapPage({
    Key? key,
    required this.userName,
    required this.userEmail,
    required this.userId,
  }) : super(key: key);

  @override
  _LocationMapPageState createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  final ApiService _apiService = ApiService();
  GoogleMapController? _mapController;
  LatLng _selectedLocation = LatLng(3.1390, 101.6869); // Default to Kuala Lumpur
  bool _isLoading = false;
  Set<Marker> _markers = {};

  // Form controllers
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _streetNameController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  void _updateMarkers() {
    _markers = {
      Marker(
        markerId: MarkerId('selected_location'),
        position: _selectedLocation,
        infoWindow: InfoWindow(title: 'Selected Location'),
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Map takes 40% of the screen
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation,
                          zoom: 12.0,
                        ),
                        markers: _markers,
                        onTap: (latLng) {
                          setState(() {
                            _selectedLocation = latLng;
                            _updateMarkers();
                            _isLoading = true; // Show loading while getting address
                          });
                          
                          // Get address from the tapped location and populate form
                          _getAddressFromLatLng(_selectedLocation).then((_) {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          });
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Long: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 80,
                        right: 16,
                        child: FloatingActionButton(
                          heroTag: "locationBtn",
                          backgroundColor: Colors.white,
                          mini: true,
                          onPressed: _getCurrentLocation,
                          child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              )
                            : Icon(
                                Icons.my_location,
                                color: Colors.blue,
                              ),
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Form takes 60% of the screen
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Address Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _buildingNameController,
                    labelText: 'Building Name',
                    hintText: 'Enter building name',
                    icon: Icons.business,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _unitNameController,
                    labelText: 'Unit Number',
                    hintText: 'Enter unit number/name',
                    icon: Icons.apartment,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _streetNameController,
                    labelText: 'Street Name',
                    hintText: 'Enter street name',
                    icon: Icons.add_road,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _postalCodeController,
                    labelText: 'Postal Code',
                    hintText: 'Enter postal code',
                    icon: Icons.local_post_office,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _cityController,
                    labelText: 'City',
                    hintText: 'Enter city',
                    icon: Icons.location_city,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _countryController,
                    labelText: 'Country',
                    hintText: 'Enter country',
                    icon: Icons.flag,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Location',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  void _saveLocation() async {
    // Validate form fields
    if (_streetNameController.text.isEmpty || 
        _postalCodeController.text.isEmpty || 
        _cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in at least the street, postal code, and city'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Create address object with form data and coordinates
    final addressData = {
      'buildingName': _buildingNameController.text,
      'unitName': _unitNameController.text,
      'streetName': _streetNameController.text,
      'postalCode': _postalCodeController.text,
      'city': _cityController.text,
      'country': _countryController.text,
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'userId': widget.userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      // Send to backend API using ApiService
      final response = await _apiService.saveLocation(addressData);

      // Hide loading indicator
      Navigator.pop(context);

      if (response.statusCode == 200) {
        // Parse response using the convert namespace
        final responseData = convert.jsonDecode(response.body);
        
        // Add the locationId to the addressData
        addressData['locationId'] = responseData['locationId'];
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to previous screen with the address data
        Navigator.pop(context, addressData);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save location: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator
      Navigator.pop(context);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error saving location: $e');
    }
  }

  // Update your _getCurrentLocation method:
  Future<void> _getCurrentLocation() async {
    if (_isLoading || !mounted) return; // Add mounted check
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them in settings.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied. Please allow access in app settings.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in app settings.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        _isLoading = false;
      });
      
      // Move camera to the current location
      _moveToPosition(_selectedLocation);

      // Try to get address details from coordinates
      _getAddressFromLatLng(_selectedLocation);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      print('Location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Enhanced method to get address details
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        print('Found placemark: $place');
        
        // More robust address field mapping with corrected properties
        setState(() {
          // For building name, use a combination of available fields
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
        
        // Show a success toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address found for this location'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No address details found for this location'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        print('No address details found for this location');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error getting address: $e');
    }
  }

  // Replace the old map movement method with this one
  void _moveToPosition(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 15.0,
        ),
      ),
    );
  }
}