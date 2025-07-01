import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import
import '../../constants.dart'; // Add this import
import '../api_service.dart'; // Add this import for ApiService

// Add theme constants - new addition
class AppTheme {
  // Primary colors
  static const Color primary = Color(0xFF3F51B5);       // Royal Blue
  static const Color secondary = Color(0xFF9C27B0);     // Vibrant Violet
  static const Color background = Color(0xFFFAFAFF);    // Ghost White
  
  // Text colors
  static const Color textHeading = Color(0xFF2E2E2E);   // Dark Slate Gray
  static const Color textBody = Color(0xFF6E6E6E);      // Slate Grey
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);       // Spring Green
  static const Color warning = Color(0xFFFF7043);       // Coral
  
  // Icon backgrounds
  static const Color iconBgBlue = Color(0xFFE3F2FD);    // Blue tint
  static const Color iconBgPurple = Color(0xFFF3E5F5);  // Purple tint
  
  // Navigation
  static const Color navInactive = Color(0xFF9E9E9E);   // Grey
}

class BookingDetailPageInProgress extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPageInProgress({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageInProgressState createState() => _BookingDetailPageInProgressState();
}

class _BookingDetailPageInProgressState extends State<BookingDetailPageInProgress> {
  final ApiService _apiService = ApiService(); // Create instance of API service
  bool _isLoading = true;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  String? _errorMessage;
  
  // Map controller
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _locationUpdateTimer;
  
  // Default center of map (will be updated when handyman location is received)
  LatLng _center = const LatLng(3.1390, 101.6869); // Kuala Lumpur

  // Add this property to your class
  Set<Polyline> _polylines = {};
  
  // Add this line to fix the error
  String _statusBannerText = 'Waiting for handyman...';

  // Add these properties to your class
  // double _previousZoom = 15.0;

  List<LatLng> _polylineCoordinates = [];
  // PolylinePoints _polylinePoints = PolylinePoints();
  String _distance = "Calculating...";
  String _duration = "Calculating...";

  // Add controller for draggable card
  final DraggableScrollableController _dragController = DraggableScrollableController();
  bool _isCardExpanded = false; // Keep this false by default
  
  // Add padding state for map
  EdgeInsets _mapPadding = EdgeInsets.only(bottom: 0);
  
  // Add BitmapDescriptor for custom marker
  BitmapDescriptor _handymanMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _fetchBookingDetails();
    _createCustomMarkerIcon(); // Add this line to create custom marker
    
    // Add listener to draggable controller to update map padding
    _dragController.addListener(_updateMapPadding);
    
    // Add this: Initialize the draggable sheet to minimized state after widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dragController.jumpTo(0.15); // Set to minimized position
      }
    });
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _dragController.removeListener(_updateMapPadding);
    super.dispose();
  }

  // New method to update map padding based on sheet position
  void _updateMapPadding() {
    if (!mounted) return;
    
    final sheetSize = _dragController.size;
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingBottom = screenHeight * sheetSize;
    
    setState(() {
      _mapPadding = EdgeInsets.only(bottom: paddingBottom);
    });
    
    // Also update camera position to ensure markers are visible
    if (_markers.length >= 2) {
      _adjustMapForMarkers(padding: paddingBottom);
    }
  }
  
  // New method to adjust map camera ensuring markers are visible with padding
  void _adjustMapForMarkers({required double padding}) {
    if (_mapController == null || _markers.length < 2) return;
    
    final bounds = _getBounds(_markers);
    
    // Fix: Use only two parameters - bounds and a single padding value
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        50.0, // Use a single uniform padding value
      ),
    );
    
    // Note: The bottom padding is already handled by the GoogleMap's padding property
  }

  Future<void> _fetchBookingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch booking details using ApiService
      final bookingResponse = await _apiService.getBookingDetails(widget.bookingId);

      if (bookingResponse.statusCode == 200) {
        final bookingData = json.decode(bookingResponse.body);
        
        // Fetch handyman details if assigned using ApiService
        if (bookingData['assigned_to'] != null) {
          try {
            final handymanResponse = await _apiService.getHandyman(bookingData['assigned_to']);
            
            if (handymanResponse.statusCode == 200) {
              final handymanData = json.decode(handymanResponse.body);
              
              setState(() {
                _handymanDetails = handymanData;
              });
              
              // Start tracking handyman location
              _startLocationTracking(bookingData['assigned_to']);
            }
          } catch (e) {
            print('Error fetching handyman details: $e');
          }
        }
        
        // Set customer location on map if available
        if (bookingData['latitude'] != null && bookingData['longitude'] != null) {
          final double lat = double.parse(bookingData['latitude'].toString());
          final double lng = double.parse(bookingData['longitude'].toString());
          
          setState(() {
            _center = LatLng(lat, lng);
            
            _markers.add(
              Marker(
                markerId: const MarkerId('customer_location'),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: 'Your Location',
                  snippet: bookingData['address'] ?? 'Service Address',
                ),
              ),
            );
          });
        }
        
        setState(() {
          _bookingDetails = bookingData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load booking details: ${bookingResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _startLocationTracking(String handymanId) {
    // Set up a timer to update the handyman's location every 10 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateHandymanLocation(handymanId);
    });
    
    // Fetch location immediately
    _updateHandymanLocation(handymanId);
  }

  // Modify the _updateHandymanLocation method to include a path
  Future<void> _updateHandymanLocation(String handymanId) async {
    try {
      final response = await _apiService.getHandymanLocation(handymanId);
      
      if (response.statusCode == 200) {
        final locationData = json.decode(response.body);
        
        // Print location data for debugging
        print('Handyman location: $locationData');
        
        if (locationData['latitude'] != null && locationData['longitude'] != null) {
          final double lat = double.parse(locationData['latitude'].toString());
          final double lng = double.parse(locationData['longitude'].toString());
          final String lastUpdated = locationData['lastUpdated'] ?? 'Unknown';
          
          // Format last updated time to be more readable
          String formattedTime = 'Just now';
          try {
            final DateTime updateTime = DateTime.parse(lastUpdated);
            final DateTime now = DateTime.now();
            final difference = now.difference(updateTime);
            
            if (difference.inMinutes < 2) {
              formattedTime = 'Just now';
            } else if (difference.inMinutes < 60) {
              formattedTime = '${difference.inMinutes} minutes ago';
            } else {
              formattedTime = '${difference.inHours} hours ago';
            }
          } catch (e) {
            print('Error parsing last updated time: $e');
          }
          
          setState(() {
            // Update or add the handyman marker
            _markers.removeWhere((marker) => marker.markerId.value == 'handyman_location');
            
            _markers.add(
              Marker(
                markerId: const MarkerId('handyman_location'),
                position: LatLng(lat, lng),
                icon: _handymanMarkerIcon, // Use the custom icon
                infoWindow: InfoWindow(
                  title: '${_handymanDetails['name'] ?? 'Handyman'} (On the way)',
                  snippet: 'Last updated: $formattedTime',
                ),
              ),
            );
            
            // Move camera to fit both handyman and customer location
            if (_mapController != null) {
              // Only move camera if customer marker exists
              if (_markers.any((marker) => marker.markerId.value == 'customer_location')) {
                _adjustMapForMarkers(padding: _mapPadding.bottom);
              } else {
                _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
              }
            }
          });

          // In your _updateHandymanLocation method, calculate ETA
          String eta = 'Calculating...';
          if (_markers.any((marker) => marker.markerId.value == 'customer_location')) {
            eta = _calculateDuration(_polylineCoordinates);
          }

          // Update the status banner text
          setState(() {
            _statusBannerText = eta;
          });

          // Inside _updateHandymanLocation
          if (_markers.any((marker) => marker.markerId.value == 'customer_location')) {
            final handymanPosition = LatLng(lat, lng);
            
            // Find customer marker
            final customerMarker = _markers.firstWhere(
              (marker) => marker.markerId.value == 'customer_location',
            );
            
            // Get directions between handyman and customer
            _getPolylinePoints(handymanPosition, customerMarker.position);
          }
        } else if (locationData['isOutdated'] == true) {
          // Handle outdated location
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Handyman location data is outdated')),
          );
        }
      } else {
        print('Failed to get handyman location: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error updating handyman location: $e');
    }
  }

  // Helper function to calculate bounds for multiple markers
  LatLngBounds _getBounds(Set<Marker> markers) {
    if (markers.isEmpty) return LatLngBounds(northeast: _center, southwest: _center);
    
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;
    
    for (var marker in markers) {
      final position = marker.position;
      minLat = min(minLat, position.latitude);
      maxLat = max(maxLat, position.latitude);
      minLng = min(minLng, position.longitude);
      maxLng = max(maxLng, position.longitude);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  // void _onMapCreated(GoogleMapController controller) {
  //   print('Map created successfully');
  //   _mapController = controller;
  // }

  String _formatDate(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _formatTime(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp);
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return 'Unknown time';
    }
  }

  // Update the buildInfoRow method styling
  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.iconBgBlue, // Updated to theme color
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppTheme.primary, // Updated to theme color
              ),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textBody, // Updated to theme color
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textHeading, // Updated to theme color
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add method to launch phone call
  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }
  
  // Add helper method to mask phone number
  String _maskPhoneNumber(String phone) {
    if (phone.length <= 4) return phone;
    String last4 = phone.substring(phone.length - 4);
    String masked = '●●●●-●●●●-$last4';
    return masked;
  }

  // Add method to create custom marker icon from asset
  Future<void> _createCustomMarkerIcon() async {
    try {
      // Create a custom marker from an asset image
      final BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/handyman_marker.png', // Make sure this asset exists in your pubspec.yaml
      );
      
      // Update the marker icon if successful
      setState(() {
        _handymanMarkerIcon = customIcon;
      });
      
      print('Custom marker icon created successfully');
    } catch (e) {
      // Keep using the default marker if there's an error
      print('Error creating custom marker: $e');
      // Fall back to default red marker if custom marker fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // Updated to theme color
      appBar: AppBar(
        title: const Text(
          'In Progress', 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600,
            color: Colors.white, // White text for contrast
          )
        ),
        backgroundColor: AppTheme.primary, // Updated to theme color
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white), // White icons
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary), // Updated to theme color
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.warning, // Updated to theme color
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.warning), // Updated to theme color
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBookingDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, // Updated to theme color
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Full-screen map - keep existing functionality
                    GoogleMap(
                      // ...existing code for map...
                      padding: _mapPadding,
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 16,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_mapController != null && _markers.length >= 2) {
                          Future.delayed(Duration(milliseconds: 500), () {
                            _adjustMapForMarkers(padding: MediaQuery.of(context).size.height * 0.25);
                          });
                        }
                      },
                    ),
                    
                    // Distance and ETA - update styling
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12), // More rounded
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.textHeading.withOpacity(0.1), // Softer shadow
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.iconBgBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_outlined,
                                    size: 14,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Distance: $_distance',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textHeading,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.iconBgPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ETA: $_duration',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textHeading,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Handyman information card
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.textHeading.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Handyman name row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.iconBgPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _handymanDetails['name'] ?? 'Handyman',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textHeading,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Call button row - removed phone number display
                            Row(
                              children: [
                                if (_handymanDetails['phone'] != null)
                                  InkWell(
                                    onTap: () => _launchPhoneCall(_handymanDetails['phone']),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.call,
                                            size: 14,
                                            color: AppTheme.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Call',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    'No phone number available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textBody,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Floating booking details card
                    DraggableScrollableSheet(
                      initialChildSize: 0.19, // Change from 0.25 to 0.15
                      minChildSize: 0.19,
                      maxChildSize: 0.5,
                      controller: _dragController,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.textHeading.withOpacity(0.08), // Softer shadow
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Status banner styling update
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary, // Updated to theme color
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.directions_outlined, // Outlined icon style
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _statusBannerText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Handle indicator
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              
                              // Header with booking details title
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.iconBgBlue, // Updated to theme color
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined, // Outlined icon style
                                        color: AppTheme.primary, // Updated to theme color
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Booking Details',
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context).size.width * 0.045,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textHeading,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        _isCardExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                        color: AppTheme.primary, // Updated to theme color
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isCardExpanded = !_isCardExpanded;
                                          _dragController.animateTo(
                                            _isCardExpanded ? 0.5 : 0.15,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Scrollable content - mostly reuse existing structure
                              Expanded(
                                child: ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                    // Service details
                                    _buildInfoRow(
                                      'Service Type', 
                                      _bookingDetails['category'] ?? 'Not specified',
                                      icon: Icons.home_repair_service_outlined, // Outlined icon
                                    ),
                                    _buildInfoRow(
                                      'Date', 
                                      _bookingDetails['starttimestamp'] != null 
                                          ? _formatDate(_bookingDetails['starttimestamp'])
                                          : 'Unknown',
                                      icon: Icons.calendar_today_outlined, // Outlined icon
                                    ),
                                    _buildInfoRow(
                                      'Time', 
                                      _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null 
                                          ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                                          : 'Unknown',
                                      icon: Icons.access_time_outlined, // Outlined icon
                                    ),
                                    _buildInfoRow(
                                      'Address', 
                                      _bookingDetails['address'] ?? 'Address not provided',
                                      icon: Icons.location_on_outlined, // Outlined icon
                                    ),
                                    
                                    if (_bookingDetails['description'] != null && _bookingDetails['description'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.background, // Updated to theme background
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: const BoxDecoration(
                                                    color: AppTheme.iconBgPurple, // Purple tint background
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.description_outlined, // Outlined icon
                                                    size: 16,
                                                    color: AppTheme.secondary, // Secondary color
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Notes:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppTheme.textHeading, // Updated color
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _bookingDetails['description'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                                color: AppTheme.textBody, // Updated color
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    // Add extra space at bottom for comfortable scrolling
                                    const SizedBox(height: 40),
                                  ],
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

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Add this function to your class
  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      print('Location permission granted');
      // Reload map or handle permission granted
    } else {
      print('Location permission denied');
      // Handle denied permission
    }
  }

  // This method fetches the route and draws the polyline
  Future<void> _getPolylinePoints(LatLng origin, LatLng destination) async {
    PolylinePoints polylinePoints = PolylinePoints();

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: google_api_key, // Use the named parameter
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
        wayPoints: [], // Empty waypoints array
      ),
    );

    if (result.points.isNotEmpty) {
      _polylineCoordinates.clear(); // Clear previous points
      for (PointLatLng point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("poly"),
            color: Colors.blue,
            points: _polylineCoordinates,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // Update distance and duration with estimated values
        _distance = _calculateDistance(_polylineCoordinates).toStringAsFixed(1) + " km";
        _duration = _calculateDuration(_polylineCoordinates);
      });
    } else {
      print("No points found in the polyline result");
      if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
        print("Error: ${result.errorMessage}");
      }
    }
  }

  // Helper method to calculate distance from polyline points
  double _calculateDistance(List<LatLng> points) {
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _haversineDistance(points[i], points[i + 1]);
    }
    return totalDistance;
  }

  double _haversineDistance(LatLng start, LatLng end) {
    final earthRadius = 6371.0; // km
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLon = _degreesToRadians(end.longitude - start.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) * 
        cos(_degreesToRadians(end.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Helper method to calculate duration from distance
  String _calculateDuration(List<LatLng> points) {
    // Assume average speed of 30 km/h
    final distance = _calculateDistance(points);
    final timeInHours = distance / 30.0;
    final timeInMinutes = (timeInHours * 60).round();
    
    if (timeInMinutes < 1) {
      return "Arrived";
    } else if (timeInMinutes < 60) {
      return "$timeInMinutes min";
    } else {
      final hours = timeInMinutes ~/ 60;
      final minutes = timeInMinutes % 60;
      return "$hours h $minutes min";
    }
  }
}