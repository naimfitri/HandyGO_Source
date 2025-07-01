import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Add this import
import 'dart:math'; // Add this import
import 'api_service.dart';
import 'invoice_dialog.dart';

// Theme colors - to match your other pages
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

class BookingPage extends StatefulWidget {
  final String userId;

  const BookingPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // Now we have 5 tabs for the different job statuses
    _tabController = TabController(length: 5, vsync: this);
    
    print('⚠️ BookingPage initialized with userId: ${widget.userId}');
    
    _fetchJobs();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('⚠️ Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('⚠️ Location permissions are denied.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('⚠️ Location permissions are permanently denied.');
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      print('⚠️ Current position: $_currentPosition');
    } catch (e) {
      print('⚠️ Error getting location: $e');
    }
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('⚠️ Fetching jobs for handyman ID: ${widget.userId}');
      
      final result = await _apiService.getHandymanJobs(widget.userId);
      print('⚠️ API response: $result');

      if (result['success']) {
        final jobsList = List<Map<String, dynamic>>.from(result['jobs']);
        print('⚠️ Fetched ${jobsList.length} jobs');
        
        // Process each job to convert slot into proper time frame if needed
        for (final job in jobsList) {
          // If the job has a slot value prefixed with "Slot", convert it
          if (job['assigned_slot'] is String && 
              job['assigned_slot'].toString().startsWith('Slot ')) {
            // Extract the slot number
            final slotNumber = job['assigned_slot'].toString().substring(5);
            // Store just the number for conversion later
            job['assigned_slot'] = slotNumber;
          }
        }
        
        setState(() {
          _jobs = jobsList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('⚠️ Error fetching jobs: $e');
      setState(() {
        _errorMessage = 'Failed to load jobs: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    return _jobs.where((job) => job['status'] == status).toList();
  }

  // Add this helper method to convert slot numbers to time frames
  String _getTimeFrameFromSlot(String? slot) {
    if (slot == null) return '';
    
    switch (slot) {
      case '1':
        return '8:00 AM - 12:00 PM';
      case '2':
        return '1:00 PM - 5:00 PM';
      case '3':
        return '6:00 PM - 10:00 PM';
      default:
        return slot; // Return the original value if not a recognized slot
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
                'My Bookings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // You can adjust size as needed
                ),
              ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        // Remove the refresh button from actions
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'In-Progress'),
            Tab(text: 'Completed-Unpaid'),
            Tab(text: 'Completed-Paid'),
          ],
        ),
      ),
      // Add floating action button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() => _isLoading = true);
          _fetchJobs().then((_) {});
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.refresh_outlined, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchJobs(),
        color: AppTheme.primaryColor,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 70,
                      color: AppTheme.warningColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textBodyColor),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchJobs,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _buildTabBarView(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildJobsList('Pending'),
        _buildJobsList('Accepted'),
        _buildJobsList('In-Progress'),
        _buildJobsList('Completed-Unpaid'),
        _buildJobsList('Completed-Paid'),
      ],
    );
  }

  Widget _buildJobsList(String status) {
    final filteredJobs = _jobs.where((job) => job['status'] == status).toList();
    
    if (filteredJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getEmptyStateBackgroundColor(status),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getEmptyStateIcon(status),
                size: 50,
                color: _getStatusColor(status),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No $status jobs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textHeadingColor,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _getEmptyStateMessage(status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textBodyColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredJobs.length,
      itemBuilder: (context, index) {
        final job = filteredJobs[index];
        return _buildJobCard(context, job);
      },
    );
  }

  Color _getEmptyStateBackgroundColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.withOpacity(0.1);
      case 'Accepted':
        return AppTheme.successColor.withOpacity(0.1);
      case 'In-Progress':
        return AppTheme.primaryColor.withOpacity(0.1);
      case 'Completed-Unpaid':
        return AppTheme.secondaryColor.withOpacity(0.1);
      case 'Completed-Paid':
        return Colors.teal.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  IconData _getEmptyStateIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty_outlined;
      case 'Accepted':
        return Icons.check_circle_outline;
      case 'In-Progress':
        return Icons.handyman_outlined;
      case 'Completed-Unpaid':
        return Icons.payments_outlined;
      case 'Completed-Paid':
        return Icons.paid_outlined;
      default:
        return Icons.work_outline;
    }
  }

  String _getEmptyStateMessage(String status) {
    switch (status) {
      case 'Pending':
        return 'You don\'t have any pending job requests at the moment';
      case 'Accepted':
        return 'You haven\'t accepted any jobs yet';
      case 'In-Progress':
        return 'You don\'t have any jobs currently in progress';
      case 'Completed-Unpaid':
        return 'You don\'t have any completed jobs awaiting payment';
      case 'Completed-Paid':
        return 'You don\'t have any paid completed jobs in your history';
      default:
        return 'No jobs found';
    }
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    // Format dates
    final startTime = DateTime.parse(job['starttimestamp']);
    final endTime = DateTime.parse(job['endtimestamp']);
    
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');
    
    final date = dateFormatter.format(startTime);
    final timeRange = '${timeFormatter.format(startTime)} - ${timeFormatter.format(endTime)}';
    
    final status = job['status'];
    Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showBookingDetails(context, job),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job['category'] ?? 'Unknown Service',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textHeadingColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  job['description'] ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textBodyColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.blueTintBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, 
                                size: 16, 
                                color: AppTheme.primaryColor
                              ),
                              const SizedBox(width: 6),
                              Text(
                                date,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textHeadingColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time_outlined, 
                                size: 16, 
                                color: AppTheme.primaryColor
                              ),
                              const SizedBox(width: 6),
                              Text(
                                job['assigned_slot'] != null ? 
                                  _getTimeFrameFromSlot(job['assigned_slot']) : timeRange,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textHeadingColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, 
                      size: 16, 
                      color: AppTheme.secondaryColor
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatAddress(job['address']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textBodyColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (_shouldShowActionButtons(status))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Divider(color: Colors.grey.withOpacity(0.2)),
                  ),
                  
                // Bottom action buttons based on status
                if (_shouldShowActionButtons(status))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildJobActionButtons(job),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowActionButtons(String status) {
    return status == 'Pending' || status == 'Accepted' || status == 'In-Progress';
  }

  Widget _buildJobActionButtons(Map<String, dynamic> job) {
    final status = job['status'];
    
    switch (status) {
      case 'Pending':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warningColor,
                side: BorderSide(color: AppTheme.warningColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _updateJobStatus(job['booking_id'], 'Rejected'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _updateJobStatus(job['booking_id'], 'Accepted'),
            ),
          ],
        );
        
      case 'Accepted':
        // Check if current time is within job's scheduled time
        final bool isWithinScheduledTime = _isWithinScheduledTime(job);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Primary button - only enabled if within scheduled time
            ElevatedButton.icon(
              icon: const Icon(Icons.engineering_outlined, size: 18),
              label: const Text('Start Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: isWithinScheduledTime 
                ? () => _updateJobStatus(job['booking_id'], 'In-Progress')
                : null, // Disabled if not within scheduled time
            ),
            
            // Secondary "Force Start" option
            if (!isWithinScheduledTime)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.warning_amber_outlined, size: 16),
                  label: const Text('Force Start Job'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showForceStartConfirmation(job),
                ),
              ),
          ],
        );
        
      case 'In-Progress':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Navigate button
            OutlinedButton.icon(
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('Navigate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _navigateToLocation(job),
            ),
            
            // Materials button
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _showInvoiceItemsDialog(job),
            ),
          ],
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  // Add method to check if current time is within scheduled job time
  bool _isWithinScheduledTime(Map<String, dynamic> job) {
    final now = DateTime.now();
    
    try {
      // Parse job date
      final startTime = DateTime.parse(job['starttimestamp']);
      final endTime = DateTime.parse(job['endtimestamp']);
      
      // Check if job has assigned slot
      if (job['assigned_slot'] != null) {
        // Get today's date
        final today = DateTime(now.year, now.month, now.day);
        
        // Check if job is scheduled for today
        final jobDate = DateTime(startTime.year, startTime.month, startTime.day);
        final isToday = jobDate.isAtSameMomentAs(today);
        
        // If not scheduled for today, job is not within time
        if (!isToday) return false;
        
        // Get slot time ranges for today
        final slot = job['assigned_slot'].toString();
        
        switch (slot) {
          case '1': // Morning slot: 8:00 AM - 12:00 PM
            final slotStart = DateTime(now.year, now.month, now.day, 8, 0);
            final slotEnd = DateTime(now.year, now.month, now.day, 12, 0);
            return now.isAfter(slotStart) && now.isBefore(slotEnd);
            
          case '2': // Afternoon slot: 1:00 PM - 5:00 PM
            final slotStart = DateTime(now.year, now.month, now.day, 13, 0);
            final slotEnd = DateTime(now.year, now.month, now.day, 17, 0);
            return now.isAfter(slotStart) && now.isBefore(slotEnd);
            
          case '3': // Evening slot: 6:00 PM - 10:00 PM
            final slotStart = DateTime(now.year, now.month, now.day, 18, 0);
            final slotEnd = DateTime(now.year, now.month, now.day, 22, 0);
            return now.isAfter(slotStart) && now.isBefore(slotEnd);
            
          default:
            // For custom slots, use original start/end times
            return now.isAfter(startTime) && now.isBefore(endTime);
        }
      }
      
      // If no slot, check if current time is between start and end time
      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      debugPrint('Error checking scheduled time: $e');
      return false; // Default to not within time on error
    }
  }

  // Add method to show force start confirmation dialog
  void _showForceStartConfirmation(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text('Force Start Job?'),
            ],
          ),
          content: const Text(
            'This job is not scheduled for the current time. Are you sure you want to start it now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _updateJobStatus(job['booking_id'], 'In-Progress');
              },
              child: const Text('START ANYWAY'),
            ),
          ],
        );
      },
    );
  }

  String _formatAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address not provided';
    }
    
    // Try to shorten the address to show just the main parts
    final parts = address.split(',');
    if (parts.length > 3) {
      return '${parts[0]}, ${parts[parts.length - 3]}, ${parts[parts.length - 2]}';
    }
    return address;
  }

  Future<void> _updateJobStatus(String bookingId, String status) async {
    try {
      setState(() => _isLoading = true);
      
      final result = await _apiService.updateJobStatus(bookingId, status);
      
      // Handle refund process if the booking is rejected
      if (status == 'Rejected' && result['success']) {
        // Show a processing refund dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(width: 16),
                  Text('Processing Refund'),
                ],
              ),
              content: Text('Refunding booking fee to customer...'),
            );
          },
        );
        
        // Process the refund
        try {
          final refundResult = await _apiService.refundBookingFee(bookingId);
          // Close the processing dialog
          Navigator.of(context).pop();
          
          if (refundResult['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                    SizedBox(width: 12),
                    Text('Booking rejected and fee refunded to customer'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: EdgeInsets.all(10),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 12),
                    Text('Booking rejected but refund may be delayed: ${refundResult['error']}'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: EdgeInsets.all(10),
              ),
            );
          }
        } catch (e) {
          // Close the processing dialog on error
          Navigator.of(context).pop();
          debugPrint('Error processing refund: $e');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 12),
                  Text('Booking rejected but refund processing failed'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: EdgeInsets.all(10),
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 12),
                  Text('Job status updated to $status'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['error'];
            _isLoading = false;
          });
        }
      }
      _fetchJobs(); // Refresh the job list
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 12),
              Text('Error: $e'),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  // Function to navigate to the job location using Google Maps
  void _navigateToLocation(Map<String, dynamic> job) async {
    if (job['latitude'] == null || job['longitude'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 12),
              const Text('Location coordinates not available'),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    final lat = job['latitude'];
    final lng = job['longitude'];
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 12),
              const Text('Could not open maps. Please make sure you have Google Maps installed.'),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  // Function to show the dialog for adding/editing invoice items used
  void _showInvoiceItemsDialog(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (BuildContext context) => InvoiceDialog(
        bookingId: job['booking_id'],
        onItemsUpdated: () {
          // Just refresh jobs list to update data
          _fetchJobs();
        },
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JobDetailsSheet(
        job: job,
        onJobStatusChanged: (bookingId, newStatus) {
          Navigator.pop(context); // Close the sheet
          _updateJobStatus(bookingId, newStatus); // Update job status
        },
        onInvoiceUpdated: () {
          // Just refresh the job list to reflect invoice items changes
          _fetchJobs();
        },
        onNavigate: _navigateToLocation,
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
        return AppTheme.successColor;
      case 'In-Progress':
        return AppTheme.primaryColor;
      case 'Completed-Unpaid':
        return AppTheme.secondaryColor;
      case 'Completed-Paid':
        return Colors.teal;
      case 'Rejected':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }
}

class JobDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> job;
  final Function(String, String) onJobStatusChanged;
  final Function() onInvoiceUpdated;
  final Function(Map<String, dynamic>) onNavigate;

  const JobDetailsSheet({
    Key? key,
    required this.job,
    required this.onJobStatusChanged,
    required this.onInvoiceUpdated,
    required this.onNavigate,
  }) : super(key: key);

  @override
  State<JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends State<JobDetailsSheet> {
  late Map<String, dynamic> _job;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _invoiceItems = [];
  
  // Add user data state variables
  bool _loadingUserData = false;
  String _userName = 'Loading...';
  String _userPhone = 'Loading...';
  
  // Add Google Maps controller
  GoogleMapController? _mapController;
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _fetchInvoiceItems();
    _fetchUserData(); // Add this to fetch user data
  }

  // Add this method to fetch user data
  Future<void> _fetchUserData() async {
    if (_job['user_id'] == null) {
      setState(() {
        _userName = 'Unknown User';
        _userPhone = 'No phone provided';
      });
      return;
    }

    setState(() {
      _loadingUserData = true;
    });

    try {
      final userId = _job['user_id'].toString();
      final result = await _apiService.getUserData(userId);

      if (result['success'] && result['userData'] != null) {
        setState(() {
          _userName = result['userData']['name'] ?? 'Unknown User';
          _userPhone = result['userData']['phone']?.toString() ?? 'No phone provided';
          
          // Update the job object with this information
          _job = {
            ..._job,
            'user_name': _userName,
            'user_phone': _userPhone,
          };
        });
      } else {
        setState(() {
          _userName = 'Data not available';
          _userPhone = 'Data not available';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        _userName = 'Error loading data';
        _userPhone = 'Error loading data';
      });
    } finally {
      setState(() {
        _loadingUserData = false;
      });
    }
  }

  Future<void> _fetchInvoiceItems() async {
    if (_job['status'] != 'In-Progress' && _job['status'] != 'Completed-Unpaid' && _job['status'] != 'Completed-Paid') {
      return; // Only fetch invoice items for relevant job statuses
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.getInvoice(_job['booking_id']);

      if (result['success'] && result['invoice'] != null) {
        final invoice = result['invoice'];
        final items = <Map<String, dynamic>>[];
        
        // Extract invoice items from the new structure
        if (invoice['items'] != null) {
          final itemsMap = Map<String, dynamic>.from(invoice['items']);
          
          itemsMap.forEach((itemId, itemData) {
            items.add({
              'id': itemId,
              'name': itemData['itemName'] ?? 'Unknown Item',
              'quantity': itemData['quantity'] ?? 0,
              'price': itemData['pricePerUnit'] ?? 0.0,
              'total': itemData['total'] ?? 0.0,
            });
          });
        }
        
        setState(() {
          _invoiceItems = items;
          // Also update the total_fare in the job object if available
          if (invoice['fare'] != null) {
            _job = {
              ..._job,
              'totalFare': invoice['fare'],
            };
          }
        });
      } else {
        setState(() {
          _invoiceItems = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching invoice: $e');
      setState(() {
        _invoiceItems = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showInvoiceItemsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => InvoiceDialog(
        bookingId: _job['booking_id'],
        onItemsUpdated: () {
          _fetchInvoiceItems(); // Refresh invoice items in this sheet
          widget.onInvoiceUpdated(); // Notify parent to refresh jobs
        },
      ),
    );
  }

  String _getTimeFrameFromSlot(String? slot) {
    if (slot == null) return '';
    
    switch (slot) {
      case '1':
        return '8:00 AM - 12:00 PM';
      case '2':
        return '1:00 PM - 5:00 PM';
      case '3':
        return '6:00 PM - 10:00 PM';
      default:
        return slot; // Return the original value if not a recognized slot
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(_job['starttimestamp']);
    final endTime = DateTime.parse(_job['endtimestamp']);
    final dateFormatter = DateFormat('EEEE, MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');
    final status = _job['status'];
    final statusColor = _getStatusColor(status);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar at top
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Booking detail header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _job['category'] ?? 'Unknown Service',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textHeadingColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _job['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.blueTintBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateFormatter.format(startTime),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textHeadingColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _job['assigned_slot'] != null ? 
                              _getTimeFrameFromSlot(_job['assigned_slot']) : 
                              '${timeFormatter.format(startTime)} - ${timeFormatter.format(endTime)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textHeadingColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Booking details content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    'Description',
                    _job['description'] ?? 'No description provided',
                    icon: Icons.description_outlined,
                  ),
                  
                  _buildDetailSection(
                    'Address',
                    _job['address'] ?? 'No address provided',
                    icon: Icons.location_on_outlined,
                    iconColor: AppTheme.secondaryColor,
                  ),
                  
                  // Add map section to show job location
                  if (_job['latitude'] != null && _job['longitude'] != null)
                    _buildMapSection(),
                  
                  _buildDetailSection(
                    'Booking ID',
                    _job['booking_id'] ?? 'Unknown',
                    icon: Icons.receipt_long_outlined,
                    iconColor: AppTheme.primaryColor,
                  ),
                  
                  // Replace User ID section with User Name and Phone
                  _buildDetailSection(
                    'User Name',
                    _loadingUserData ? 'Loading...' : (_job['user_name'] ?? _userName),
                    icon: Icons.person_outlined,
                    iconColor: AppTheme.secondaryColor,
                  ),
                  
                  _buildDetailSection(
                    'User Phone',
                    _loadingUserData 
                      ? 'Loading...' 
                      : (() {
                          String phone = _job['user_phone'] ?? _userPhone ?? '';
                          if (phone.isNotEmpty && !phone.startsWith('0')) {
                            phone = '0' + phone;
                          }
                          return phone;
                        })(),
                    icon: Icons.phone_outlined,
                    iconColor: AppTheme.secondaryColor,
                  ),
                  
                  // Created at information
                  if (_job['created_at'] != null)
                    _buildDetailSection(
                      'Request Created',
                      DateFormat('MMM d, yyyy - h:mm a').format(DateTime.parse(_job['created_at'])),
                      icon: Icons.history_outlined,
                    ),
                    
                  // Add Invoice details for in-progress and completed jobs
                  if (_job['status'] == 'In-Progress' || _job['status'] == 'Completed-Unpaid' || _job['status'] == 'Completed-Paid')
                    _buildInvoiceSection(),
                ],
              ),
            ),
          ),
          
          // Action buttons based on status
          _buildDetailActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    if (_invoiceItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No invoice items added yet',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textBodyColor,
              ),
            ),
            if (_job['totalFare'] != null && _job['totalFare'] > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.blueTintBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Service Fare:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    Text(
                      'RM ${(_job['totalFare'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    // Calculate item total
    double itemsTotal = 0;
    for (final item in _invoiceItems) {
      itemsTotal += (item['quantity'] ?? 0) * (item['price'] ?? 0);
    }
    
    // Get the service fare
    double serviceFare = _job['totalFare']?.toDouble() ?? 0;
    
    // Calculate the full subtotal - fare PLUS items
    double totalAmount = serviceFare + itemsTotal;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ..._invoiceItems.map<Widget>((item) {
            final itemTotal = (item['quantity'] ?? 0) * (item['price'] ?? 0);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.blueTintBackground.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Unknown Item',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppTheme.textHeadingColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Quantity: ${item['quantity'] ?? 0} × RM ${item['price']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            color: AppTheme.textBodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'RM ${itemTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          
          // Summary section with the correct calculation
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.blueTintBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                // Items total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items Subtotal:',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    Text(
                      'RM ${itemsTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                  ],
                ),
                
                // Service fare
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    height: 1,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Service Fare:',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    Text(
                      'RM ${serviceFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                  ],
                ),
                
                // Total amount (fare + items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    height: 1,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Invoice Amount:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textHeadingColor,
                      ),
                    ),
                    Text(
                      'RM ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Only show Edit Invoice button for In-Progress jobs
          if (_job['status'] == 'In-Progress')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _showInvoiceItemsDialog,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHeadingColor,
          ),
        ),
      ],
    );
  }
  
  // Add this new method for the map section
  Widget _buildMapSection() {
    final latitude = double.tryParse(_job['latitude'].toString()) ?? 0.0;
    final longitude = double.tryParse(_job['longitude'].toString()) ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.map_outlined,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHeadingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary( // Add this wrapper around the map
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude, longitude),
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    
                    // Add marker for job location
                    final markerId = MarkerId('jobLocation');
                    final marker = Marker(
                      markerId: markerId,
                      position: LatLng(latitude, longitude),
                      infoWindow: InfoWindow(
                        title: 'Job Location',
                        snippet: _job['address'] ?? 'No address provided',
                      ),
                    );
                    
                    setState(() {
                      _markers[markerId] = marker;
                    });
                  },
                  markers: _markers.values.toSet(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(Icons.directions, size: 16, color: AppTheme.primaryColor),
                label: Text('Navigate', style: TextStyle(color: AppTheme.primaryColor)),
                onPressed: () => widget.onNavigate(_job),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: AppTheme.blueTintBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppTheme.primaryColor,
                ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHeadingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: title == 'User Phone' && content != 'Loading...' && content != 'Data not available' && content != 'Error loading data' && content != 'No phone provided'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          content,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textBodyColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _makePhoneCall(content),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.phone,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textBodyColor,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
 void _makePhoneCall(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Just open dialer, don't include 'tel://' (only 'tel:')
    final String numberWithZero =
      cleanedNumber.startsWith('0') ? cleanedNumber : '0$cleanedNumber';

    final Uri phoneUri = Uri(scheme: 'tel', path: numberWithZero);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri, mode: LaunchMode.platformDefault);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not launch phone dialer'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Widget _buildDetailActionButtons() {
    final status = _job['status'];
    
    switch (status) {
      case 'Pending':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onJobStatusChanged(_job['booking_id'], 'Rejected'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppTheme.warningColor,
                    side: BorderSide(color: AppTheme.warningColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onJobStatusChanged(_job['booking_id'], 'Accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        
      case 'Accepted':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          
        );
        
      case 'In-Progress':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: _buildSlideToCompleteButton(),
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSlideToCompleteButton() {
    // Calculate total invoice amount
    double totalInvoiceAmount = _job['totalFare']?.toDouble() ?? 0.0;
    
    // Add total from invoice items if any
    if (_invoiceItems.isNotEmpty) {
      for (final item in _invoiceItems) {
        totalInvoiceAmount += (item['quantity'] ?? 0) * (item['price'] ?? 0);
      }
    }
    
    // Check if total invoice is 0
    bool hasZeroInvoice = totalInvoiceAmount <= 0;
    
    return Column(
      children: [
        // Show warning message if invoice total is 0
        if (hasZeroInvoice)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Cannot complete job with zero invoice amount. Please add service fare or items.",
                    style: TextStyle(color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),
          
        // Show slider button (disabled if invoice total is 0)
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double sliderWidth = MediaQuery.of(context).size.width - 20;

              return hasZeroInvoice
                ? Container(
                    width: sliderWidth,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        "Add invoice items or fare to complete job",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : CustomSliderButton(
                    width: sliderWidth,
                    height: 60,
                    backgroundColor: const Color.fromARGB(255, 190, 186, 186),
                    buttonColor: AppTheme.successColor,
                    label: "Slide to finish job",
                    onConfirm: () async {
                      widget.onJobStatusChanged(_job['booking_id'], 'Completed-Unpaid');
                    },
                  );
            },
          ),
        ),
        
        // Show button to open invoice dialog if total is zero
        if (hasZeroInvoice)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              onPressed: _showInvoiceItemsDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Invoice Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }




  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
        return AppTheme.successColor;
      case 'In-Progress':
        return AppTheme.primaryColor;
      case 'Completed-Unpaid':
        return AppTheme.secondaryColor;
      case 'Completed-Paid':
        return Colors.teal;
      case 'Rejected':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }
  
  // Add this method to build the invoice section
  Widget _buildInvoiceSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long,
                size: 20,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Invoice Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              const Spacer(),
              if (_job['status'] == 'Completed-Unpaid')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Payment Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                )
              else if (_job['status'] == 'Completed-Paid')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading 
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            : _buildInvoiceItemsList(), 
        ],
      ),
    );
  }
}

// Custom slider button implementation
class CustomSliderButton extends StatefulWidget {
  final double width;
  final double height;
  final Color backgroundColor;
  final Color buttonColor;
  final String label;
  final Function onConfirm;

  const CustomSliderButton({
    Key? key,
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.buttonColor,
    required this.label,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<CustomSliderButton> createState() => _CustomSliderButtonState();
}

class _CustomSliderButtonState extends State<CustomSliderButton> with SingleTickerProviderStateMixin {
  double _position = 0;
  bool _isDragging = false;
  bool _isConfirmed = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller)
      ..addListener(() {
        setState(() {
          _position = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetPosition() {
    _animation = Tween<double>(begin: _position, end: 0).animate(_controller);
    _controller.reset();
    _controller.forward();
    _isDragging = false;
  }

  void _checkForConfirmation() {
    if (_position > widget.width - 70) {
      setState(() {
        _isConfirmed = true;
      });
      widget.onConfirm();
    } else {
      _resetPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.height - 10;
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Progress indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: _position,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.buttonColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          ),
          
          // Label text
          Positioned.fill(
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xff4a4a4a),
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          
          // Draggable button
          Positioned(
            left: _position,
            child: GestureDetector(
              onHorizontalDragStart: (_) {
                _isDragging = true;
              },
              onHorizontalDragUpdate: (details) {
                if (_isDragging) {
                  setState(() {
                    _position += details.delta.dx;
                    // Constrain position
                    if (_position < 0) _position = 0;
                    if (_position > widget.width - buttonSize) _position = widget.width - buttonSize;
                  });
                }
              },
              onHorizontalDragEnd: (_) {
                _checkForConfirmation();
              },
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: widget.buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 30.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
