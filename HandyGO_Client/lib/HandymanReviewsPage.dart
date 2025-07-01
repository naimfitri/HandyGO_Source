import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'WriteReviewPage.dart';
import 'api_service.dart';

class HandymanReviewsPage extends StatefulWidget {
  final String handymanId;
  final String handymanName;

  const HandymanReviewsPage({
    Key? key,
    required this.handymanId,
    required this.handymanName,
  }) : super(key: key);

  @override
  _HandymanReviewsPageState createState() => _HandymanReviewsPageState();
}

class _HandymanReviewsPageState extends State<HandymanReviewsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  Map<int, int> _ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  String? _errorMessage;
  Map<String, dynamic>? _handymanData;
  List<String> _expertise = [];
  String _profession = "";
  String _location = "";
  String _experience = "";
  List<String> _availability = [];

  @override
  void initState() {
    super.initState();
    _fetchHandymanData();
    _fetchReviews();
  }

  Future<void> _fetchHandymanData() async {
    try {
      final response = await _apiService.getHandymanDetails(widget.handymanId);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _handymanData = data;
          
          // Extract expertise - handle both array and string formats
          if (data['expertise'] is List) {
            _expertise = List<String>.from(data['expertise']);
          } else if (data['expertise'] is String) {
            _expertise = [data['expertise']];
          }
          
          _profession = _expertise.isNotEmpty ? _expertise[0] : "Handyman";
          _location = data['city'] ?? "New York";
          _experience = data['experience'] ?? "10";
          
          // Extract availability days
          if (data['schedule'] is Map) {
            _availability = [];
            data['schedule'].forEach((day, status) {
              if (status == 'available') {
                _availability.add(day);
              }
            });
          }
        });
      }
    } catch (e) {
      print('Error fetching handyman data: $e');
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getHandymanReviews(widget.handymanId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final List<Map<String, dynamic>> reviews = [];
        double totalRating = 0;
        Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        
        if (data['reviews'] != null) {
          for (var review in data['reviews']) {
            reviews.add(Map<String, dynamic>.from(review));
            // Handle the rating properly - could be double in the API response
            num ratingValue = review['rating'] ?? 0;
            double ratingDouble = ratingValue.toDouble();
            int ratingInt = ratingValue.round(); // Round to nearest integer for the counts
            
            totalRating += ratingDouble;
            
            if (ratingInt >= 1 && ratingInt <= 5) {
              ratingCounts[ratingInt] = (ratingCounts[ratingInt] ?? 0) + 1;
            }
          }
        }
        
        final double averageRating = reviews.isEmpty ? 0 : totalRating / reviews.length;
        
        // Sort reviews - newest first
        reviews.sort((a, b) {
          final aTime = a['timestamp'] ?? 0;
          final bTime = b['timestamp'] ?? 0;
          return bTime.compareTo(aTime);
        });
        
        setState(() {
          _reviews = reviews;
          _averageRating = averageRating;
          _ratingCounts = ratingCounts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load reviews: ${response.statusCode}';
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

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        leading: BackButton(),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildHandymanProfile(),
      // floatingActionButton removed
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
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchReviews,
            child: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandymanProfile() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(),
          
          // Expertise Section
          _buildExpertiseSection(),
          
          // Reviews Section
          _buildReviewsSection(),
          
          SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: _handymanData != null && _handymanData!['profileImage'] != null
                ? Image.network(
                    _handymanData!['profileImage'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.blue[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.blue[100],
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue[700],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.blue[100],
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.blue[700],
                    ),
                  ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          widget.handymanName,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _location,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            Text(
              ' • $_experience years experience',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Divider(),
      ],
    );
  }

  Widget _buildExpertiseSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expertise',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _expertise.map((skill) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          Divider(),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                'Ratings & Reviews',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _averageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 8),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Reviews list
          _reviews.isEmpty
              ? Center(
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : Column(
                  children: _reviews.map((review) => _buildReviewItem(review)).toList(),
                ),
                
          SizedBox(height: 16),
          Divider(),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final reviewText = review['review'] ?? '';
    final userName = review['userName'] ?? 'Anonymous';
    final timestamp = review['timestamp'] ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formatDate(timestamp),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
          SizedBox(height: 8),
          Text(
            reviewText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Divider(),
        ],
      ),
    );
  }
}
