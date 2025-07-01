import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../api_service.dart';

// Define consistent style constants
class AppStyles {
  // Colors
  static const Color primaryColor = Color(0xFF3F51B5); // Royal Blue
  static const Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
  static const Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
  static const Color headingTextColor = Color(0xFF2E2E2E); // Dark Slate Gray
  static const Color bodyTextColor = Color(0xFF6E6E6E); // Slate Grey
  static const Color successColor = Color(0xFF4CAF50); // Spring Green
  static const Color warningColor = Color(0xFFFF7043); // Coral
  static const Color iconBgBlue = Color(0xFFE3F2FD); // Blue tint
  static const Color iconBgPurple = Color(0xFFF3E5F5); // Purple tint
  
  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: headingTextColor,
  );
  
  static const TextStyle subHeadingStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: headingTextColor,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: bodyTextColor,
  );
  
  // Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  );
}

class BookingDetailPageAccepted extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPageAccepted({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageAcceptedState createState() =>
      _BookingDetailPageAcceptedState();
}

class _BookingDetailPageAcceptedState extends State<BookingDetailPageAccepted> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  String? _errorMessage;
  
  // Animation controller for page elements
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController, 
      curve: Curves.easeInOut,
    );
    
    _fetchBookingDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookingResponse = await _apiService.getBookingDetails(widget.bookingId);

      if (bookingResponse.statusCode == 200) {
        final bookingData = json.decode(bookingResponse.body);

        if (bookingData['assigned_to'] != null) {
          try {
            final handymanResponse = await _apiService.getHandyman(bookingData['assigned_to']);
            if (handymanResponse.statusCode == 200) {
              setState(() {
                _handymanDetails = json.decode(handymanResponse.body);
              });
            }
          } catch (e) {
            print('Error fetching handyman details: $e');
          }
        }

        setState(() {
          _bookingDetails = bookingData;
          _isLoading = false;
        });
        
        // Start animation after data is loaded
        _animationController.forward();
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

  String _formatExpertise(dynamic expertise) {
    if (expertise == null) return 'General';
    if (expertise is List) {
      return expertise.join(', ');
    } else {
      return expertise.toString();
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppStyles.bodyTextColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppStyles.headingTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppStyles.iconBgBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppStyles.primaryColor, size: 18),
          ),
          SizedBox(width: 12),
        ],
        Text(
          title,
          style: AppStyles.headingStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppStyles.primaryColor,
        title: Text('Booking Details', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppStyles.primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContentWithAnimation(),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: AppStyles.warningColor.withOpacity(0.7),
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: AppStyles.warningColor),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchBookingDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContentWithAnimation() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppStyles.successColor.withOpacity(0.1),
                border: Border.all(color: AppStyles.successColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppStyles.successColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_outline, color: AppStyles.successColor),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIRMED',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.successColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Handyman has accepted your booking',
                          style: TextStyle(
                            color: AppStyles.successColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Handyman Card
            if (_handymanDetails.isNotEmpty) _buildHandymanCard(),
            SizedBox(height: 16),

            // Service Details
            _buildServiceDetailsCard(),
            SizedBox(height: 16),

            // Location Card
            _buildLocationCard(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandymanCard() {
    return Container(
      decoration: AppStyles.cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              // Handyman detail action could be added here
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Handyman Details', icon: Icons.person_outline),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Hero(
                        tag: 'handyman-${_handymanDetails['id']}',
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppStyles.iconBgBlue,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (_handymanDetails['name'] ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                color: AppStyles.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _handymanDetails['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.headingTextColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.handyman_outlined,
                                  size: 14,
                                  color: AppStyles.bodyTextColor,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatExpertise(_handymanDetails['expertise']),
                                    style: TextStyle(color: AppStyles.bodyTextColor),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppStyles.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.call_outlined,
                                      size: 16,
                                      color: AppStyles.primaryColor),
                                  SizedBox(width: 8),
                                  Text(
                                    _handymanDetails['phone'] ?? 'No phone',
                                    style: TextStyle(
                                      color: AppStyles.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_right, color: AppStyles.bodyTextColor),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildServiceDetailsCard() {
    final hasDescription = _bookingDetails['description'] != null && 
                           _bookingDetails['description'].toString().isNotEmpty;
    
    return Container(
      decoration: AppStyles.cardDecoration,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Service Details', icon: Icons.build_outlined),
            SizedBox(height: 16),
            
            // Enhanced service type display
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppStyles.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _bookingDetails['category'] ?? 'Unknown',
                style: TextStyle(
                  color: AppStyles.secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 16),
            
            _buildInfoRow('Booking ID', _bookingDetails['booking_id'] ?? 'Unknown'),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
            
            _buildInfoRow(
              'Date',
              _bookingDetails['starttimestamp'] != null
                ? _formatDate(_bookingDetails['starttimestamp'])
                : 'Unknown'
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
            
            _buildInfoRow(
              'Time',
              _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null
                ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                : 'Unknown'
            ),
            
            // Add notes section inside service details card
            if (hasDescription) ...[
              Divider(height: 24, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppStyles.iconBgPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.description_outlined, color: AppStyles.secondaryColor, size: 16),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppStyles.bodyTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  _bookingDetails['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppStyles.bodyTextColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationCard() {
    return Container(
      decoration: AppStyles.cardDecoration,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Location', icon: Icons.location_on_outlined),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyles.iconBgPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.home_outlined, color: AppStyles.secondaryColor, size: 18),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bookingDetails['address'] ?? 'No address provided',
                        style: TextStyle(
                          color: AppStyles.headingTextColor,
                          fontSize: 14,
                        ),
                      ),
                      if (_bookingDetails['latitude'] != null && _bookingDetails['longitude'] != null)
                        TextButton.icon(
                          onPressed: () {
                            // Map navigation action could be added here
                          },
                          icon: Icon(Icons.map_outlined, size: 16),
                          label: Text('View on map'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppStyles.primaryColor,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Keep the method for other components that might use it
  Widget _buildNotesCardIfNeeded() {
    // Method kept but no longer called in the main UI
    if (_bookingDetails['description'] == null || _bookingDetails['description'].toString().isEmpty) {
      return SizedBox.shrink();
    }
    
    return Container(
      decoration: AppStyles.cardDecoration,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Notes', icon: Icons.note_outlined),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Text(
                _bookingDetails['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.bodyTextColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
