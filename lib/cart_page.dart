import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'token_service.dart'; // Import the new token service

import 'order_page.dart';
import 'home.dart';
import 'search_page.dart';
import 'address_page.dart';
import 'profile_page.dart';

// --- Cart Data Structure for Frontend ---
class CartItem {
  final String id; // MongoDB _id of the item in the cart (for update/delete)
  final String productId; // MongoDB _id of the product
  final String name;
  final String imageUrl;
  final int price; // priceAtAddition
  int count; // Mutable quantity
  final String quantityLabel = "Unit"; // Placeholder as this isn't in backend model

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.count,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productData = json['product'] as Map<String, dynamic>;

    // Fix for localhost
    String imageUrl = productData['imageUrl'] ?? '';
    if (imageUrl.contains('localhost')) {
      imageUrl = imageUrl.replaceAll('http://localhost:8000', renderBaseUrl);
    } else if (imageUrl.contains('10.0.2.2')) {
      imageUrl = imageUrl.replaceAll('http://10.0.2.2:8000', renderBaseUrl);
    }

    return CartItem(
      id: json['_id'],
      productId: productData['_id'],
      name: productData['pname'] ?? 'N/A',
      imageUrl: imageUrl,
      price: json['priceAtAddition'] ?? productData['price'] ?? 0,
      count: json['quantity'],
    );
  }
}

// --- CartPage Widget ---
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  int _totalItems = 0;
  int _subtotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  // Function to handle API errors and show a snackbar
  void _showApiError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- API Functions ---

  /// Fetches the user's cart from the backend
  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await getAccessToken();
      if (token == null) {
        _showApiError("Authentication failed. Please log in.");
        setState(() { _isLoading = false; });
        return;
      }

      final url = Uri.parse('$baseUrl/cart/');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> itemsData = responseBody['data']['items'];

        setState(() {
          _cartItems = itemsData.map((data) => CartItem.fromJson(data)).toList();
          _calculateTotals();
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // Cart is empty
        setState(() {
          _cartItems = [];
          _calculateTotals();
          _isLoading = false;
        });
      } else {
        final responseBody = jsonDecode(response.body);
        _showApiError(responseBody['message'] ?? 'Failed to fetch cart.');
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (kDebugMode) print("Fetch Cart Error: $e");
      if (mounted) _showApiError("Network error. Could not load cart.");
      setState(() { _isLoading = false; });
    }
  }

  /// Updates the quantity of a specific cart item
  Future<void> _updateItemQuantity(String itemId, int newQuantity) async {
    if (newQuantity < 1) return _removeItem(itemId);

    final itemIndex = _cartItems.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final oldQuantity = _cartItems[itemIndex].count;

    // Optimistic UI update
    setState(() {
      _cartItems[itemIndex].count = newQuantity;
      _calculateTotals();
    });

    try {
      final token = await getAccessToken();
      final url = Uri.parse('$baseUrl/cart/item/$itemId');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"quantity": newQuantity}),
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        if (mounted) {
          _showApiError("Failed to update quantity on server.");
          setState(() {
            _cartItems[itemIndex].count = oldQuantity;
            _calculateTotals();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Update Cart Error: $e");
      // Rollback on network failure
      if (mounted) {
        _showApiError("Network error. Could not update cart.");
        setState(() {
          _cartItems[itemIndex].count = oldQuantity;
          _calculateTotals();
        });
      }
    }
  }

  /// Removes a specific cart item
  Future<void> _removeItem(String itemId) async {
    final itemIndex = _cartItems.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final CartItem itemToRemove = _cartItems[itemIndex];

    // Optimistic UI update
    setState(() {
      _cartItems.removeAt(itemIndex);
      _calculateTotals();
    });

    try {
      final token = await getAccessToken();
      final url = Uri.parse('$baseUrl/cart/item/$itemId');

      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        if (mounted) {
          _showApiError("Failed to remove item from cart on server.");
          setState(() {
            _cartItems.insert(itemIndex, itemToRemove);
            _calculateTotals();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Remove Cart Error: $e");
      // Rollback on network failure
      if (mounted) {
        _showApiError("Network error. Could not remove item.");
        setState(() {
          _cartItems.insert(itemIndex, itemToRemove);
          _calculateTotals();
        });
      }
    }
  }

  /// Clears the entire cart
  Future<void> _clearCart() async {
    final List<CartItem> backupItems = List.from(_cartItems);

    // Optimistic UI update
    setState(() {
      _cartItems = [];
      _calculateTotals();
    });

    try {
      final token = await getAccessToken();
      final url = Uri.parse('$baseUrl/cart/clear');

      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        if (mounted) {
          _showApiError("Failed to clear cart on server.");
          setState(() {
            _cartItems = backupItems;
            _calculateTotals();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cart cleared!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print("Clear Cart Error: $e");
      // Rollback on network failure
      if (mounted) {
        _showApiError("Network error. Could not clear cart.");
        setState(() {
          _cartItems = backupItems;
          _calculateTotals();
        });
      }
    }
  }

  // --- Utility Functions ---

  void _calculateTotals() {
    _subtotal = _cartItems.fold(
      0,
          (sum, item) => sum + item.price * item.count,
    );
    _totalItems = _cartItems.fold(
      0,
          (sum, item) => sum + item.count,
    );
  }

  // --- Widget Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Cart",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _cartItems.isEmpty ? null : _clearCart,
            child: const Text("Clear Cart", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SearchPage()),
            );
          } else if (index == 2) {
            // Already on Cart
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyOrderPage()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Cart",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Order"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
          ? const Center(
        child: Text(
          "Your cart is empty! Start shopping.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildOrderSummary(),
            _buildProceedButton(),
            const SizedBox(height: 10),
            ListView.builder(
              itemCount: _cartItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return _buildCartItemCard(item, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Order Summery",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Subtotal", style: TextStyle(fontSize: 16)),
              Text(
                "₹$_subtotal",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Part of your order qualifies for FREE Delivery. Choose this option at checkout.",
                  style: TextStyle(fontSize: 13, color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(value: false, onChanged: (value) {}),
              const Expanded(
                child: Text(
                  "Send as a gift. Include personalized message.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProceedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _cartItems.isEmpty ? null : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddressPage(),
            ),
          );
        },
        child: Text(
          "Proceed to Check out ($_totalItems item${_totalItems != 1 ? 's' : ''})",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image (Using Image.network)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 30),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${item.name} (${item.quantityLabel})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "₹${item.price * item.count}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "In stock",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity Selector and Remove Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      _updateItemQuantity(item.id, item.count - 1);
                    },
                  ),
                  Text(
                    "${item.count}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _updateItemQuantity(item.id, item.count + 1);
                    },
                  ),
                ],
              ),

              // Remove Button
              SizedBox(
                height: 35,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _removeItem(item.id),
                  child: const Text("Remove"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}