import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/stripe_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe_pkg;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

// Define the color scheme constants
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF5C6BC0); // Indigo
  static const Color primaryLight = Color(0xFF8E99F3);
  static const Color primaryDark = Color(0xFF26418F);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A); // Teal
  static const Color secondaryLight = Color(0xFF64D8CB);
  static const Color secondaryDark = Color(0xFF00766C);
  
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

class WalletPage extends StatefulWidget {
  final String userId;
  final String userName;
  final double initialWalletBalance;

  const WalletPage({
    Key? key,
    required this.userId,
    required this.userName,
    required this.initialWalletBalance,
  }) : super(key: key);

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double walletAmount = 0.0;
  List<Map<String, dynamic>> activityHistory = [];
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessingPayment = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    walletAmount = widget.initialWalletBalance;
    _fetchUserWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserWalletData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch user wallet balance
      final userSnapshot = await _database.child('users/${widget.userId}').get();
      
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>?;
        if (userData != null && userData['wallet'] != null) {
          setState(() {
            walletAmount = double.parse(userData['wallet'].toString());
          });
        }
      }
      
      // Fetch transactions
      await fetchActivityHistory();
    } catch (error) {
      print("Error fetching wallet data: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching wallet data: $error")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchActivityHistory() async {
    try {
      final transactionsSnapshot = await _database
          .child('walletTransactions')
          .orderByChild('userId')
          .equalTo(widget.userId)
          .get();
      
      if (transactionsSnapshot.exists) {
        final data = transactionsSnapshot.value as Map<dynamic, dynamic>?;
        
        if (data != null) {
          final List<Map<String, dynamic>> transactions = [];
          
          data.forEach((key, value) {
            if (value is Map) {
              final transaction = Map<String, dynamic>.from(
                value.map((k, v) => MapEntry(k.toString(), v))
              );
              
              transaction['id'] = key;
              transactions.add(transaction);
            }
          });
          
          // Sort by timestamp (descending)
          transactions.sort((a, b) {
            final aTime = a['timestamp'] ?? 0;
            final bTime = b['timestamp'] ?? 0;
            return bTime.compareTo(aTime);
          });
          
          setState(() {
            activityHistory = transactions.map((transaction) {
              final timestamp = transaction['timestamp'];
              DateTime dateTime = DateTime.now();
              if (timestamp != null) {
                if (timestamp is int) {
                  dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                } else if (timestamp is String) {
                  try {
                    dateTime = DateTime.parse(timestamp);
                  } catch (e) {
                    print("Error parsing timestamp: $e");
                  }
                }
              }
              
              return {
                'id': transaction['id'] ?? '',
                'userId': transaction['userId'] ?? '',
                'amount': double.parse(transaction['amount'].toString()),
                'timestamp': dateTime,
                'transactionType': transaction['transactionType'] ?? 'unknown',
                'userName': transaction['userName'] ?? widget.userName,
                'paymentMethod': transaction['paymentMethod'] ?? 'standard',
                'description': transaction['description'] ?? '',
                'recipient': transaction['recipient'] ?? 'Service Provider',
                'bookingId': transaction['bookingId'] ?? '',
              };
            }).toList();
          });
        }
      } else {
        setState(() {
          activityHistory = [];
        });
      }
    } catch (error) {
      print("Error fetching activity history: $error");
    }
  }

  Future<void> _refreshWalletData() async {
    return _fetchUserWalletData();
  }

  Future<void> _showTopUpDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Top Up Wallet",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              SizedBox(height: 24),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Enter Amount (MYR)",
                  labelStyle: TextStyle(color: AppColors.textBody),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  hintText: "e.g. 10.00",
                  prefixIcon: Icon(Icons.monetization_on, color: AppColors.primary),
                ),
                autofocus: true,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    processStripePayment();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card),
                      SizedBox(width: 12),
                      Text("Pay with Card", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> processStripePayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a valid amount."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final result = await StripeService.processPayment(
        amount: amount,
        userId: widget.userId,
        userName: widget.userName,
      );

      if (result['success'] == true) {
        await _refreshWalletData();
        _amountController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment successful! Wallet updated."),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment failed: ${result['error']}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error processing payment: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _refreshWalletData,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: AppColors.primary,
                    pinned: true,
                    elevation: 0,
                    leadingWidth: 40,
                    title: Text(
                      "HandyPay Wallet",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  // Wallet Header with gradient background
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWalletHeader(),
                          _buildActionButtons(),
                          SizedBox(height: 16),
                          
                          // Security notice with improved design
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.shield, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Secured wallet transactions",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  
                  // Transactions header with card design
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Wallet transactions",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHeading,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Transaction list or empty state
                  activityHistory.isEmpty 
                      ? SliverFillRemaining(
                          child: _buildEmptyTransactions(),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final transaction = activityHistory[index];
                              return _buildTransactionItem(transaction);
                            },
                            childCount: activityHistory.length,
                          ),
                        ),
                  
                  // Add bottom padding
                  SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
      // Floating action button for top-up
      floatingActionButton: _isLoading ? null : FloatingActionButton(
        onPressed: _showTopUpDialog,
        backgroundColor: AppColors.secondary,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: "Top up wallet",
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available Balance",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "MYR ",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          walletAmount.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Center(
        child: Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showTopUpDialog,
            icon: Icon(Icons.add_card, size: 20),
            label: Text(
              "Top Up Wallet",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            "No transactions yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Top up your wallet to get started with seamless payments for your services",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showTopUpDialog,
            icon: Icon(Icons.add_card, size: 18),
            label: Text("Add Funds"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] as double;
    final isPositive = transaction['transactionType'] == 'top-up' || 
                      transaction['transactionType'] == 'refund' ||
                      transaction['transactionType'] == 'earnings' ||
                      transaction['transactionType'] == 'auto-refund' ||
                      transaction['transactionType'] == 'refund rejected booking';
    final transactionType = transaction['transactionType'] as String? ?? 'unknown';
    final timestamp = transaction['timestamp'] as DateTime;
    final bookingId = transaction['bookingId'] as String? ?? '';
    final desc = transaction['description'] ?? _getTransactionTypeText(transactionType, amount);
    final recipient = transaction['recipient'] ?? '';

    // Select appropriate icon based on transaction type
    IconData transactionIcon = _getTransactionIcon(transactionType);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Optional: Show transaction details on tap
          _showTransactionDetails(transaction);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Transaction type icon
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transactionType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      transactionIcon,
                      color: _getTransactionColor(transactionType),
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // Transaction details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTransactionDisplayLabel(transactionType),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textHeading,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDate(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount
                  Text(
                    "${isPositive ? '+ ' : '- '}MYR ${amount.abs().toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              
              // Optional additional details
              if (desc.isNotEmpty && desc != _getTransactionDisplayLabel(transactionType) || 
                  recipient.isNotEmpty || 
                  bookingId.isNotEmpty) 
                Container(
                  margin: EdgeInsets.only(top: 12, left: 44),
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desc.isNotEmpty && desc != _getTransactionDisplayLabel(transactionType))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            desc,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      if (recipient.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Text(
                                "Recipient: ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textBody.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                recipient,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (bookingId.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              "Booking: ",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textBody.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              bookingId.substring(0, min(8, bookingId.length)) + "...",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textBody,
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
      ),
    );
  }

  // Helper method to show transaction details
  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getTransactionColor(transaction['transactionType']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTransactionIcon(transaction['transactionType']),
                        color: _getTransactionColor(transaction['transactionType']),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTransactionDisplayLabel(transaction['transactionType']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHeading,
                            ),
                          ),
                          Text(
                            _formatDetailedDate(transaction['timestamp']),
                            style: TextStyle(
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 16),

                // Amount
                _buildDetailRow(
                  "Amount",
                  "${transaction['transactionType'] == 'top-up' || 
                    transaction['transactionType'] == 'refund' || 
                    transaction['transactionType'] == 'refund rejected booking' ||
                    transaction['transactionType'] == 'auto-refund' ||
                    transaction['transactionType'] == 'earnings' ? '+ ' : '- '}MYR ${(transaction['amount'] as double).abs().toStringAsFixed(2)}",
                  valueColor: transaction['transactionType'] == 'top-up' || 
                    transaction['transactionType'] == 'refund' ||
                    transaction['transactionType'] == 'refund rejected booking' ||
                    transaction['transactionType'] == 'auto-refund' ||
                    transaction['transactionType'] == 'earnings' ? AppColors.success : AppColors.error,
                  valueFontSize: 18,
                  valueBold: true,
                ),
                
                SizedBox(height: 16),

                // Transaction details
                Text(
                  "Transaction Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow("Transaction ID", transaction['id']),
                SizedBox(height: 8),
                _buildDetailRow("Type", _getTransactionDisplayLabel(transaction['transactionType'])),
                SizedBox(height: 8),
                if (transaction['description'] != null && transaction['description'].toString().isNotEmpty)
                  _buildDetailRow("Description", transaction['description']),
                SizedBox(height: 8),
                if (transaction['recipient'] != null && transaction['recipient'].toString().isNotEmpty)
                  _buildDetailRow("Recipient", transaction['recipient']),
                SizedBox(height: 8),
                if (transaction['bookingId'] != null && transaction['bookingId'].toString().isNotEmpty)
                  _buildDetailRow("Booking ID", transaction['bookingId']),
                SizedBox(height: 8),
                _buildDetailRow("Payment Method", _formatPaymentMethod(transaction['paymentMethod'])),
                
                SizedBox(height: 32),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: AppColors.textBody,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build detail rows in transaction details
  Widget _buildDetailRow(String label, String value, {
    Color? valueColor,
    double valueFontSize = 14,
    bool valueBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textBody.withOpacity(0.8),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              color: valueColor ?? AppColors.textHeading,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTransactionIcon(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'top-up':
        return Icons.add_card;
      case 'booking-fee':
        return Icons.receipt;
      case 'payment':
        return Icons.payments;
      case 'refund':
        return Icons.replay;
      case 'auto-refund':
        return Icons.autorenew;  // Auto-renew icon for automatic refund
      case 'refund rejected booking':
        return Icons.cancel;
      case 'withdrawal':
        return Icons.account_balance;
      case 'earnings':
        return Icons.attach_money;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _getTransactionColor(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'top-up':
        return AppColors.primary;
      case 'booking-fee':
        return AppColors.warning;
      case 'payment':
        return AppColors.error;
      case 'refund':
        return AppColors.secondary;
      case 'auto-refund':
        return AppColors.secondary;  // Same color as regular refund
      case 'withdrawal':
        return Color(0xFF7E57C2); // Purple
      case 'earnings':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  String _getTransactionDisplayLabel(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'top-up':
        return 'Wallet Top-Up';
      case 'booking-fee':
        return 'Booking Fee';
      case 'refund':
        return 'Refund';
      case 'auto-refund':
        return 'Automatic Refund';
      case 'withdrawal':
        return 'Withdrawal';
      case 'payment':
        return 'Service Payment';
      case 'earnings':
        return 'Earnings';
      case 'refund rejected booking':
        return 'Rejected Booking';
      default:
        return 'Transaction';
    }
  }

  String _getTransactionTypeText(String? type, double amount) {
    if (type == null) return 'Transaction';
    
    switch (type.toLowerCase()) {
      case 'top-up':
        return 'Added funds to wallet';
      case 'booking-fee':
        return 'Processing fee for booking';
      case 'refund':
        return 'Refund to wallet';
      case 'auto-refund':
        return 'Automatic refund to wallet';
      case 'withdrawal':
        return 'Withdrawn from wallet';
      case 'payment':
        return 'Paid for service';
      case 'earnings':
        return 'Earned from service';
      default:
        return amount >= 0 ? 'Credit to wallet' : 'Debit from wallet';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String _formatDetailedDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return "${date.day} ${months[date.month - 1]} ${date.year}, ${_formatTime(date)}";
  }

  String _formatTime(DateTime date) {
    String hour = date.hour.toString().padLeft(2, '0');
    String minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}";
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'card':
        return 'Credit/Debit Card';
      case 'wallet':
        return 'Wallet Balance';
      case 'bank':
        return 'Bank Transfer';
      default:
        return method;
    }
  }
}
