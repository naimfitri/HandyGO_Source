import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'WithdrawRequestPage.dart';
import 'api_service.dart';
import 'HandymanHomePage.dart';

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

class WalletPage extends StatefulWidget {
  final String userId;
  
  const WalletPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double availableBalance = 0.00;
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> transactions = [];
  String? _debugErrorMessage;
  
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }
  
  // Fetch wallet balance and transaction history
  Future<void> _fetchWalletData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Get wallet data from API
      final result = await _apiService.getHandymanWallet(widget.userId);
      
      if (result['success']) {
        // Update balance
        availableBalance = result['balance'].toDouble();
        
        // Update transactions
        if (result['transactions'] != null) {
          transactions = List<Map<String, dynamic>>.from(result['transactions']);
        } else {
          transactions = [];
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to fetch wallet data');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching wallet data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _debugErrorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: const Text(
          "Your Wallet",  // Empty title as requested
          style: TextStyle(
            color: Colors.white, 
            fontSize: 24, 
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        // Removed the refresh button from here
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: _isLoading 
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorView()
              : _buildWalletContent(),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            "Loading your wallet...",
            style: TextStyle(
              color: AppTheme.textBodyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Allow scrolling even when content is small
        child: Container(
          // Set minimum height to ensure we can always pull to refresh
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, 
                    size: 48, 
                    color: AppTheme.warningColor
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Unable to Load Wallet",
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHeadingColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We couldn't connect to the server. Please check your internet connection and try again.",
                  style: TextStyle(color: AppTheme.textBodyColor, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (_debugErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _debugErrorMessage!,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchWalletData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("Try Again", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    // Use mock data for testing
                    setState(() {
                      availableBalance = 262.00;
                      transactions = [/* mock data */];
                      _isLoading = false;
                      _hasError = false;
                    });
                  },
                  icon: const Icon(Icons.apps_outlined, size: 16),
                  label: const Text("Use Demo Data"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Add a hint about pull-to-refresh
                const Text(
                  "Pull down to refresh",
                  style: TextStyle(
                    color: AppTheme.textBodyColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildWalletContent() {
    return RefreshIndicator(
      onRefresh: _fetchWalletData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Changed from BouncingScrollPhysics to ensure it's always scrollable
        child: ConstrainedBox(
          // This ensures minimal height for scrolling when content is small
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 
                AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Wallet balance card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 24, 20, 24), // Increased bottom margin since stats are removed
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withBlue(240),
                      AppTheme.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Balance label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Available Balance",
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "RM",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            availableBalance.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      
                      // Withdraw button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            elevation: 0,
                          ),
                          onPressed: availableBalance > 0 ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WithdrawRequestPage(
                                  userId: widget.userId,
                                  availableBalance: availableBalance,
                                  onWithdrawalComplete: () {
                                    _fetchWalletData(); // Refresh data after withdrawal
                                  },
                                ),
                              ),
                            );
                          } : null,
                          icon: const Icon(Icons.account_balance_outlined, size: 20),
                          label: const Text(
                            "Withdraw Funds",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Transaction section header (removed quick stats section above this)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, 
                          color: AppTheme.primaryColor, 
                          size: 18
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Transaction History",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textHeadingColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.blueTintBackground,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        "${transactions.length} transactions",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Transaction list or empty state
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: transactions.isEmpty
                    ? _buildEmptyTransactions()
                    : Column(
                        children: [
                          ...transactions.map((transaction) => _buildTransactionCard(transaction)),
                          const SizedBox(height: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      margin: const EdgeInsets.only(top: 8, bottom: 40), // Added bottom margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.blueTintBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined, 
              color: AppTheme.primaryColor, 
              size: 32
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Transactions Yet",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: AppTheme.textHeadingColor,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Complete services to earn money and see your transaction history here",
              style: TextStyle(
                color: AppTheme.textBodyColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Add pull to refresh hint
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_downward,
                size: 14,
                color: AppTheme.textBodyColor.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                "Pull down to refresh",
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textBodyColor.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final transactionType = transaction['transactionType'] as String;
    final transactionStatus = transaction['transactionStatus'] as String? ?? 'completed';
    final amount = (transaction['amount'] as num).toDouble();
    final timestamp = transaction['timestamp'] as int;
    final description = transaction['description'] as String;
    
    // Format the timestamp
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(date);
    
    // Determine icon and colors based on transaction type
    IconData icon;
    Color iconBgColor;
    Color amountColor;
    String amountPrefix;
    
    switch (transactionType) {
      case 'earnings':
        icon = Icons.arrow_downward_rounded;
        iconBgColor = AppTheme.successColor.withOpacity(0.15);
        amountColor = AppTheme.successColor;
        amountPrefix = '+';
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward_rounded;
        iconBgColor = transactionStatus == 'pending' 
            ? Colors.amber.withOpacity(0.15)
            : AppTheme.warningColor.withOpacity(0.15);
        amountColor = transactionStatus == 'pending' 
            ? Colors.amber.shade800 
            : AppTheme.warningColor;
        amountPrefix = '-';
        break;
      default:
        icon = Icons.swap_horiz_rounded;
        iconBgColor = AppTheme.blueTintBackground;
        amountColor = AppTheme.primaryColor;
        amountPrefix = '';
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: amountColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textHeadingColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppTheme.textBodyColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: AppTheme.textBodyColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (transactionStatus == 'pending')
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pending_outlined,
                            size: 12,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Processing',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              "$amountPrefix RM ${amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
