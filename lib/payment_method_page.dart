import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// Assuming you have defined baseUrl and getAccessToken in token_service.dart
import 'token_service.dart';
import 'order_page.dart';
import 'home.dart';
import 'search_page.dart';
import 'profile_page.dart';
// Import the AddressPage data model
import 'address_page.dart';

// --------------------------------------------------------------------------
// 🎯 DATA MODELS
// --------------------------------------------------------------------------

class CartItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;

  CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice
  });

  double get subtotal => quantity * unitPrice;

  factory CartItem.fromApiJson(Map<String, dynamic> json) {
    final product = json['product'];

    // Defensive check: if product is null or not a map, return a placeholder
    if (product == null || product is! Map<String, dynamic>) {
      return CartItem(
        productId: json['product']?.toString() ?? '',
        name: 'Product details not found',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (json['priceAtAddition'] as num?)?.toDouble() ?? 0.0,
      );
    }

    return CartItem(
      productId: product['_id']?.toString() ?? '',
      // 🛠️ FIX: Backend sends 'pname', but we fallback to 'name' or 'Unknown' just in case
      name: (product['pname'] ?? product['name'] ?? 'Unknown Product').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (product['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// --------------------------------------------------------------------------
// 💳 PAYMENT PAGE IMPLEMENTATION
// --------------------------------------------------------------------------

class PaymentPage extends StatefulWidget {
  final DeliveryAddress deliveryAddress;

  const PaymentPage({
    super.key,
    required this.deliveryAddress,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<CartItem> _fetchedCartItems = [];
  bool _isLoadingCart = true;
  String? _apiError;

  String? _selectedPaymentMethod;
  bool _isProcessingOrder = false;

  double _itemSubtotal = 0.0;
  final double _shippingFee = 5.00;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = 'COD';
    _fetchCartDetails();
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- API Handlers ---

  Future<void> _fetchCartDetails() async {
    setState(() {
      _isLoadingCart = true;
      _apiError = null;
    });

    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) _showSnackBar('Authentication session expired.', color: Colors.orange);
        setState(() { _isLoadingCart = false; });
        return;
      }

      // 🛠️ FIX: Removed extra '/api/v1' because baseUrl already includes it
      final url = Uri.parse('$baseUrl/cart');

      if (kDebugMode) {
        print("🔵 FETCHING CART FROM: $url");
      }

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (kDebugMode) {
        print("🟡 RAW SERVER RESPONSE: ${response.body}");
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // --- 🔍 ROBUST PARSING LOGIC 🔍 ---
        List<dynamic> rawList = [];
        final dynamic data = responseBody['data'];

        if (data == null) {
          print("🔴 ERROR: 'data' key is null in response.");
        }
        else if (data is List) {
          // Scenario A: The data is the list itself
          rawList = data;
        }
        else if (data is Map<String, dynamic>) {
          // Scenario B: Standard { data: { items: [] } }
          if (data['items'] != null && data['items'] is List) {
            rawList = data['items'];
          }
          // Scenario C: Nested Cart Object { data: { cart: { items: [] } } }
          else if (data['cart'] != null &&
              data['cart'] is Map<String, dynamic> &&
              data['cart']['items'] != null) {
            rawList = data['cart']['items'];
          }
        }

        print("🟢 PARSED LIST LENGTH: ${rawList.length}");

        if (rawList.isEmpty) {
          setState(() {
            _fetchedCartItems = [];
            _isLoadingCart = false;
            _apiError = "Your cart is empty.";
          });
          return;
        }

        // Convert to CartItem objects safely
        final List<CartItem> items = [];
        for (var itemJson in rawList) {
          try {
            items.add(CartItem.fromApiJson(itemJson));
          } catch (e) {
            print("🔴 Error parsing specific item: $e");
            print("   Item JSON: $itemJson");
          }
        }

        setState(() {
          _fetchedCartItems = items;
          _recalculateTotals();
          _isLoadingCart = false;
        });

      } else {
        if (kDebugMode) print("🔴 Server Error: ${response.statusCode}");
        setState(() {
          _isLoadingCart = false;
          _apiError = "Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (kDebugMode) print("🔴 CRITICAL EXCEPTION: $e");
      if (mounted) {
        setState(() {
          _isLoadingCart = false;
          _apiError = "App Error: $e";
        });
      }
    }
  }

  void _recalculateTotals() {
    double newSubtotal = _fetchedCartItems.fold(0.0, (sum, item) => sum + item.subtotal);
    setState(() {
      _itemSubtotal = newSubtotal;
      _totalAmount = _itemSubtotal + _shippingFee;
    });
  }

  Future<void> _placeOrder() async {
    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method.');
      return;
    }
    if (_selectedPaymentMethod != 'COD') {
      _showSnackBar('Only "Cash on Delivery" is currently supported.', color: Colors.orange);
      return;
    }

    if (_fetchedCartItems.isEmpty) {
      _showSnackBar("Your cart is empty. Cannot place order.");
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });
    _showSnackBar('Placing order...', color: Colors.blue);

    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) _showSnackBar('Authentication required.', color: Colors.orange);
        setState(() { _isProcessingOrder = false; });
        return;
      }

      final orderPayload = {
        "items": _fetchedCartItems.map((item) => {
          "productId": item.productId,
          "quantity": item.quantity,
          "price": item.unitPrice,
        }).toList(),
        "deliveryAddress": {
          "recipientName": widget.deliveryAddress.recipientName,
          "mobileNumber": widget.deliveryAddress.mobileNumber,
          "streetAddress": widget.deliveryAddress.streetAddress,
          "apartment": widget.deliveryAddress.apartment,
          "city": widget.deliveryAddress.city,
          "postalCode": widget.deliveryAddress.postalCode,
        },
        "paymentMethod": _selectedPaymentMethod,
        "shippingFee": _shippingFee,
      };

      // 🛠️ FIX: Removed extra '/api/v1' here as well
      final url = Uri.parse('$baseUrl/order/place');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderPayload),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        _showSnackBar('Order placed successfully!', color: Colors.green);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyOrderPage()),
              (Route<dynamic> route) => route.isFirst,
        );
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar(responseBody['message'] ?? 'Failed to place order.');
        setState(() { _isProcessingOrder = false; });
      }
    } catch (e) {
      if (kDebugMode) print("Place Order Error: $e");
      if (mounted) _showSnackBar('Network error while placing order.');
      setState(() { _isProcessingOrder = false; });
    }
  }

  // --- UI Builders ---

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Order Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildSummaryRow("Item Subtotal", _itemSubtotal),
            _buildSummaryRow("Shipping Fee", _shippingFee),
            const Divider(height: 20),
            _buildSummaryRow("Total Amount", _totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 17 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.green.shade800 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    final address = widget.deliveryAddress;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ship To:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              address.recipientName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${address.streetAddress}, ${address.apartment != null && address.apartment!.isNotEmpty ? '${address.apartment}, ' : ''}${address.city} - ${address.postalCode}',
            ),
            Text('Mobile: ${address.mobileNumber}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String method, String label, IconData icon) {
    final bool isDisabled = method != 'COD';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: _selectedPaymentMethod == method ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _selectedPaymentMethod == method ? Colors.green.shade700 : Colors.grey.shade300,
          width: _selectedPaymentMethod == method ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: RadioListTile<String>(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          secondary: Icon(icon, color: Colors.green.shade700),
          value: method,
          groupValue: _selectedPaymentMethod,
          onChanged: isDisabled ? null : (value) {
            setState(() {
              _selectedPaymentMethod = value;
            });
          },
          activeColor: Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Payment Method",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoadingCart
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_fetchedCartItems.isEmpty && _apiError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Text(
                    _apiError!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                  ),
                ),
              ),

            if (_fetchedCartItems.isNotEmpty) ...[
              const Text(
                "1. Delivery Address",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildDeliveryAddressCard(),
              const SizedBox(height: 25),

              const Text(
                "2. Payment Method",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildPaymentMethodTile('COD', 'Cash on Delivery', Icons.money),
              _buildPaymentMethodTile('UPI', 'UPI Payment (Coming Soon)', Icons.qr_code_2),
              _buildPaymentMethodTile('CARD', 'Credit/Debit Card (Coming Soon)', Icons.credit_card),
              const SizedBox(height: 25),

              const Text(
                "3. Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessingOrder
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Place Order",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}