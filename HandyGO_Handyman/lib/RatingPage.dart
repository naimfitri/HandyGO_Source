import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF3F51B5);
  static const Color secondaryColor = Color(0xFF9C27B0);
  static const Color backgroundColor = Color(0xFFFAFAFF);
  static const Color textHeadingColor = Color(0xFF2E2E2E);
  static const Color textBodyColor = Color(0xFF6E6E6E);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF7043);
  static const Color blueTintBackground = Color(0xFFE3F2FD);
  static const Color purpleTintBackground = Color(0xFFF3E5F5);
}

class RatingPage extends StatefulWidget {
  final String handymanId;
  final String handymanName;

  const RatingPage({
    Key? key,
    required this.handymanId,
    required this.handymanName,
  }) : super(key: key);

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _ratings = [];
  double _averageRating = 0.0;
  Map<int, int> _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    _loadRatings();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getHandymanRatings(widget.handymanId);

      if (result['success']) {
        // Process ratings
        final rawRatings = result['ratings'];
        final List<Map<String, dynamic>> processedRatings = [];
        
        if (rawRatings is Map) {
          // Reset distribution counts
          _ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
          
          // Process each rating
          rawRatings.forEach((key, value) {
            if (value is Map) {
              final Map<String, dynamic> rating = Map<String, dynamic>.from(value);
              rating['id'] = key;
              
              // Add to processed list
              processedRatings.add(rating);
              
              // Update distribution - handle both int and double rating values
              final dynamic rawRatingValue = rating['rating'] ?? 0;
              final int ratingValue;
              
              // Convert to int regardless if it's double or int
              if (rawRatingValue is int) {
                ratingValue = rawRatingValue;
              } else if (rawRatingValue is double) {
                ratingValue = rawRatingValue.round();
              } else {
                // Handle other unexpected types by defaulting to 0
                ratingValue = 0;
              }
              
              if (ratingValue >= 1 && ratingValue <= 5) {
                _ratingDistribution[ratingValue] = (_ratingDistribution[ratingValue] ?? 0) + 1;
              }
            }
          });
          
          // Sort by timestamp (newest first)
          processedRatings.sort((a, b) {
            final aTime = a['timestamp'] ?? 0;
            final bTime = b['timestamp'] ?? 0;
            return bTime.compareTo(aTime);
          });
        }
        
        setState(() {
          _ratings = processedRatings;
          // Convert averageRating to double regardless of original type
          final dynamic rawAverageRating = result['averageRating'];
          if (rawAverageRating != null) {
            _averageRating = (rawAverageRating is int) ? rawAverageRating.toDouble() : 
                            (rawAverageRating is double) ? rawAverageRating : 0.0;
          } else {
            _averageRating = 0.0;
          }
          _totalRatings = _ratings.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load ratings';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading ratings: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ratings & Reviews', 
          style: TextStyle(fontWeight: FontWeight.w600)
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        color: AppTheme.primaryColor,
        child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              ),
            )
          : _errorMessage != null
            ? _buildErrorView()
            : _buildRatingsView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          width: double.infinity,
          margin: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_border_rounded,
                  size: 60,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load Ratings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textBodyColor,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _loadRatings,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try Again', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with handyman name and gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.handymanName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
                          color: Color.fromARGB(60, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Service Provider',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Rating summary card (elevated from background)
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Average rating display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left side - Big rating number
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.blueTintBackground,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            _averageRating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textHeadingColor,
                                            ),
                                          ),
                                          Text(
                                            '/5',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textBodyColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: _buildStarRating(_averageRating),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$_totalRatings ${_totalRatings == 1 ? 'rating' : 'ratings'}',
                                          style: TextStyle(
                                            color: AppTheme.textBodyColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Right side - Rating distribution
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((rating) {
                                final count = _ratingDistribution[rating] ?? 0;
                                final percentage = _totalRatings > 0 
                                  ? count / _totalRatings 
                                  : 0.0;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$rating',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textHeadingColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: percentage,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              _getRatingColor(rating),
                                            ),
                                            minHeight: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 28,
                                        child: Text(
                                          count.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textHeadingColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Reviews section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.comment_outlined, 
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Customer Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Reviews list or empty state
            _ratings.isEmpty
                ? _buildNoReviewsMessage()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ratings.length,
                      itemBuilder: (context, index) {
                        return _buildReviewCard(_ratings[index]);
                      },
                    ),
                  ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // Full star
          return const Icon(Icons.star_rounded, color: Colors.amber, size: 22);
        } else if (index < rating.ceil() && rating.ceil() != rating.floor()) {
          // Half star
          return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 22);
        } else {
          // Empty star
          return Icon(Icons.star_border_rounded, color: Colors.amber.withOpacity(0.7), size: 22);
        }
      }),
    );
  }

  Widget _buildNoReviewsMessage() {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.purpleTintBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_outlined,
              size: 50,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Written Reviews Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textHeadingColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ratings have been provided without written feedback',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textBodyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    // Handle both int and double rating values
    final dynamic rawRating = review['rating'] ?? 0;
    final int rating;
    
    // Convert to int regardless of original type
    if (rawRating is int) {
      rating = rawRating;
    } else if (rawRating is double) {
      rating = rawRating.round();
    } else {
      rating = 0;
    }
    
    final String reviewText = review['review'] ?? '';
    final String userName = review['userName'] ?? 'Anonymous';
    
    // Format the timestamp
    final int timestamp = review['timestamp'] ?? 0;
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final String formattedDate = DateFormat('MMM d, yyyy').format(dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info and date
            Row(
              children: [
                // User avatar with gradient background
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 18,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User name and review date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textHeadingColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textBodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRatingColor(rating).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        rating.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getRatingColor(rating),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.star,
                        color: _getRatingColor(rating),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Stars
            if (rating > 0) ...[
              const SizedBox(height: 12),
              _buildStarIcons(rating),
            ],
            
            // Review text
            if (reviewText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueTintBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reviewText,
                  style: TextStyle(
                    color: AppTheme.textBodyColor,
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStarIcons(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5:
        return const Color(0xFF388E3C); // Dark green
      case 4:
        return const Color(0xFF7CB342); // Light green
      case 3:
        return const Color(0xFFFBC02D); // Amber
      case 2:
        return const Color(0xFFFF9800); // Orange
      case 1:
        return const Color(0xFFE64A19); // Deep orange/red
      default:
        return Colors.grey;
    }
  }
}
