import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class InvoiceDialog extends StatefulWidget {
  final String bookingId;
  final Function onItemsUpdated;

  const InvoiceDialog({
    Key? key,
    required this.bookingId,
    required this.onItemsUpdated,
  }) : super(key: key);

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _invoiceItems = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _totalFareController = TextEditingController();
  bool _isAddingItem = false;
  double _totalInvoiceAmount = 0.0;
  bool _isFareManuallySet = false;

  @override
  void initState() {
    super.initState();
    _fetchInvoiceItems();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _totalFareController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoiceItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the new getInvoice method instead of getJobMaterials
      final result = await _apiService.getInvoice(widget.bookingId);

      if (result['success'] && result['invoice'] != null) {
        final invoice = result['invoice'];
        
        // Extract invoice fare
        final double fare = (invoice['fare'] ?? 0).toDouble();
        _totalFareController.text = fare.toStringAsFixed(2);
        
        // Check if fare was manually set
        final bool manualFare = invoice['manualFare'] == true;
        
        // Extract invoice items
        final items = <Map<String, dynamic>>[];
        if (invoice['items'] != null) {
          final itemsMap = Map<String, dynamic>.from(invoice['items']);
          itemsMap.forEach((itemId, itemData) {
            items.add({
              'id': itemId,
              'itemName': itemData['itemName'] ?? '',
              'quantity': itemData['quantity'] ?? 0,
              'pricePerUnit': itemData['pricePerUnit'] ?? 0.0,
              'total': itemData['total'] ?? 0.0,
            });
          });
        }
        
        setState(() {
          _invoiceItems = items;
          _totalInvoiceAmount = fare;
          _isFareManuallySet = manualFare;
        });
      } else {
        setState(() {
          _invoiceItems = [];
          _totalInvoiceAmount = 0.0;
          _totalFareController.text = "0.00";
          _isFareManuallySet = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching invoice: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addInvoiceItem() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text;
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0.0;

      if (name.isEmpty || quantity <= 0 || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields with valid values')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Store the current fare before adding item
      final currentFare = double.tryParse(_totalFareController.text) ?? _totalInvoiceAmount;
      final wasManuallySet = _isFareManuallySet;
      
      // Use the new addInvoiceItem method
      final result = await _apiService.addInvoiceItem(
        widget.bookingId, 
        name, 
        quantity, 
        price,
        wasManuallySet, // Send flag to indicate if fare was manually set
      );

      if (result['success']) {
        _nameController.clear();
        _quantityController.clear();
        _priceController.clear();
        
        // Refresh invoice items
        await _fetchInvoiceItems();
        
        // If fare was manually set before adding the item, restore that value
        if (wasManuallySet) {
          // Keep the manually set fare
          setState(() {
            _totalFareController.text = currentFare.toStringAsFixed(2);
            _totalInvoiceAmount = currentFare;
            _isFareManuallySet = true;
          });
          
          // Update the fare in the backend again to ensure it's not overridden
          await _apiService.updateInvoiceFare(
            widget.bookingId,
            currentFare,
            true,
          );
        }
        
        widget.onItemsUpdated(); // Notify parent to refresh jobs
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: ${result['error']}')),
        );
      }
    } catch (e) {
      debugPrint('Error adding invoice item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isAddingItem = false;
      });
    }
  }

  Future<void> _updateTotalFare() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final totalFare = double.tryParse(_totalFareController.text) ?? _totalInvoiceAmount;
      
      // Set the flag to indicate this is a manual update
      setState(() {
        _isFareManuallySet = true;
      });
      
      final result = await _apiService.updateInvoiceFare(
        widget.bookingId,
        totalFare,
        true, // This indicates it's a manual fare update
      );

      if (result['success']) {
        setState(() {
          _totalInvoiceAmount = totalFare;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total fare updated successfully')),
        );
        widget.onItemsUpdated(); // Notify parent to refresh jobs
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update fare: ${result['error']}')),
        );
      }
    } catch (e) {
      debugPrint('Error updating total fare: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating fare: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteInvoiceItem(String itemId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Store the current fare before deleting the item
      final currentFare = double.tryParse(_totalFareController.text) ?? _totalInvoiceAmount;
      final wasManuallySet = _isFareManuallySet;
      
      // Delete the invoice item
      final result = await _apiService.deleteInvoiceItem(
        widget.bookingId, 
        itemId,
        wasManuallySet, // Send flag to indicate if fare was manually set
      );

      if (result['success']) {
        // Refresh invoice items
        await _fetchInvoiceItems();
        
        // If fare was manually set before deleting the item, restore that value
        if (wasManuallySet) {
          setState(() {
            _totalFareController.text = currentFare.toStringAsFixed(2);
            _totalInvoiceAmount = currentFare;
            _isFareManuallySet = true;
          });
          
          // Update the fare in the backend again to ensure it's not overridden
          await _apiService.updateInvoiceFare(
            widget.bookingId,
            currentFare,
            true,
          );
        }
        
        widget.onItemsUpdated(); // Notify parent to refresh jobs
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: ${result['error']}')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting invoice item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Job Invoice'),
      content: SizedBox(
        width: double.maxFinite, 
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Total Fare Card with clear separation
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isFareManuallySet ? Colors.amber : Colors.grey[300]!,
                        width: _isFareManuallySet ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Fare Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_isFareManuallySet)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 14, color: Colors.amber[800]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Manual",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _totalFareController,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (RM)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                    
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _updateTotalFare,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Update',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          if (_invoiceItems.isNotEmpty) ...[
                            const SizedBox(height: 8),
        
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Section 2: Invoice Items List with its own card
                  Card(
                    elevation: 4,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Invoice Items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isAddingItem)
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Item'),
                                  onPressed: () {
                                    setState(() {
                                      _isAddingItem = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                          
                          // Add item form when adding
                          if (_isAddingItem) ...[
                            const SizedBox(height: 16),
                            _buildAddItemForm(),
                            const SizedBox(height: 16),
                          ],
                          
                          // List of existing items
                          if (_invoiceItems.isEmpty && !_isAddingItem)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No items added yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add materials or labor charges',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._invoiceItems.map<Widget>((item) => _buildInvoiceItemCard(item)).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // Helper method to calculate items total
  double _calculateItemsTotal() {
    double total = 0;
    for (var item in _invoiceItems) {
      total += (item['quantity'] ?? 0) * (item['pricePerUnit'] ?? 0.0);
    }
    return total;
  }

  // Helper method to build invoice item card
  Widget _buildInvoiceItemCard(Map<String, dynamic> item) {
    final subtotal = (item['quantity'] ?? 0) * (item['pricePerUnit'] ?? 0.0);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['itemName'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteInvoiceItem(item['id']),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete item',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${item['quantity'] ?? 0} × RM ${(item['pricePerUnit'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItemForm() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Item',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (RM)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingItem = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addInvoiceItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text(
                    'Add Item',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}