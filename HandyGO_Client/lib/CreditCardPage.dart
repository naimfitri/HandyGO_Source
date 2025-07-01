import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Credit Card Payment',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CreditCardPage(amount: 100.0), // Example amount
    );
  }
}

class CreditCardPage extends StatefulWidget {
  final double amount; // The amount to be charged

  const CreditCardPage({Key? key, required this.amount}) : super(key: key);

  @override
  _CreditCardPageState createState() => _CreditCardPageState();
}

class _CreditCardPageState extends State<CreditCardPage> {
  bool _isProcessing = false; // To show a loading spinner while processing
  String? _errorMessage; // To hold error messages for user feedback

  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expirationController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();

  // Simulate payment process and update Firestore
  Future<void> processPayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isProcessing = true;
        _errorMessage = null; // Reset error messages
      });

      try {
        // Simulate payment process (replace with actual payment gateway like Stripe)
        await Future.delayed(Duration(seconds: 2)); // Simulating a delay

        // After "payment" is successful, update Firestore
        await updateWalletBalance(widget.amount);

        // Navigate back to the previous page after successful payment
        Navigator.pop(context);
      } catch (error) {
        setState(() {
          _errorMessage = 'Error processing payment: $error';
        });
        print('Error processing payment: $error');
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Updates the wallet balance and logs the transaction in Firestore
  Future<void> updateWalletBalance(double amount) async {
    try {
      // Ensure the user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User is not authenticated. Please log in.';
      }

      // Reference the user's Firestore document
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Increment the wallet balance
      await userRef.update({
        'wallet': FieldValue.increment(amount),
      });

      // Log the transaction in the walletTransactions collection
      await FirebaseFirestore.instance.collection('walletTransactions').add({
        'userId': user.uid,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'transactionType': 'top-up',
        'userName': user.displayName ?? 'Unknown User',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment processed successfully!")),
      );
    } catch (error) {
      setState(() {
        _errorMessage = 'Error updating wallet balance: $error';
      });
      print('Error updating wallet balance: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Card Payment')),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator() // Show a loading spinner while processing
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Card Number Input
                          TextFormField(
                            controller: _cardNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Card Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your card number';
                              }
                              // You can add more validation rules for card format here
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          // Expiration Date Input
                          TextFormField(
                            controller: _expirationController,
                            decoration: const InputDecoration(
                              labelText: 'Expiration Date (MM/YY)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.datetime,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter expiration date';
                              }
                              // Additional validation could be added for proper MM/YY format
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          // CVC Input
                          TextFormField(
                            controller: _cvcController,
                            decoration: const InputDecoration(
                              labelText: 'CVC',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CVC';
                              }
                              // You can add validation rules for CVC format here
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Submit Button
                          ElevatedButton(
                            onPressed: processPayment,
                            child: Text('Pay MYR ${widget.amount.toStringAsFixed(2)}'),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
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
}
