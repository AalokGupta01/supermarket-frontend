import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'token_service.dart'; // Assuming this contains baseUrl and getAccessToken
import 'cart_page.dart';
import 'search_page.dart';
import 'home.dart';
import 'profile_page.dart';

// --------------------------------------------------------------------------
// 🎯 ORDER DATA MODELS
// --------------------------------------------------------------------------

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final String id;
  final double totalAmount;
  final String status; // 'Pending', 'Delivered', etc.
  final DateTime date;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.date,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var itemList = json['items'] as List?;
    List<OrderItem> parsedItems = itemList != null
        ? itemList.map((i) => OrderItem.fromJson(i)).toList()
        : [];

    return OrderModel(
      id: json['_id'] ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['orderStatus'] ?? 'Pending',
      date: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      items: parsedItems,
    );
  }
}

// --------------------------------------------------------------------------
// 📦 ORDER PAGE UI
// --------------------------------------------------------------------------

class MyOrderPage extends StatefulWidget {
  const MyOrderPage({super.key});

  @override
  State<MyOrderPage> createState() => _MyOrderPageState();
}

class _MyOrderPageState extends State<MyOrderPage> {
  int selectedTab = 0; // 0 = Current, 1 = Past
  bool _isLoading = true;
  String? _error;
  List<OrderModel> _allOrders = [];

  // Computed properties for filtering
  List<OrderModel> get _currentOrders => _allOrders.where((o) {
    final s = o.status.toLowerCase();
    return s != 'delivered' && s != 'cancelled';
  }).toList();

  List<OrderModel> get _pastOrders => _allOrders.where((o) {
    final s = o.status.toLowerCase();
    return s == 'delivered' || s == 'cancelled';
  }).toList();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // --- API Fetch Logic ---
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await getAccessToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please login to view orders.';
        });
        return;
      }

      // Ensure this matches your backend route.
      // I assumed '/order/my-orders' maps to getUserOrders
      final url = Uri.parse('$baseUrl/order/my-orders');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List ordersJson = data['data'] ?? [];

        setState(() {
          _allOrders = ordersJson.map((json) => OrderModel.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load orders. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (kDebugMode) print("Fetch Orders Error: $e");
      setState(() {
        _isLoading = false;
        _error = 'Network error. Please check your connection.';
      });
    }
  }

  // --- UI Helpers ---

  String _formatDate(DateTime date) {
    // Simple formatter: DD-MM-YYYY
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'out for delivery': return Colors.orange;
      case 'shipped': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No orders found",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        // Create a summary string of items (e.g., "Apple (2), Milk (1)")
        final itemSummary = order.items
            .map((i) => "${i.name} (${i.quantity})")
            .join(", ");

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Order ID: ...${order.id.substring(order.id.length - 6)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    _formatDate(order.date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                itemSummary,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        "₹${order.totalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // We use bottom nav, no back button usually
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Optional: Logic if you want back button functionality
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomePage()));
          },
        ),
        title: const Text(
          "My Orders",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          )
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedTab == 0 ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Current",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selectedTab == 0 ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedTab == 1 ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Past",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selectedTab == 1 ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: _fetchOrders,
                      child: const Text("Retry")
                  )
                ],
              ),
            )
                : selectedTab == 0
                ? _buildOrderList(_currentOrders)
                : _buildOrderList(_pastOrders),
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) return; // Already on Order page

          Widget nextPage;
          if (index == 0) nextPage = const HomePage();
          else if (index == 1) nextPage = const SearchPage();
          else if (index == 2) nextPage = const CartPage();
          else nextPage = const ProfilePage(); // index 4

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => nextPage),
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Cart"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Order"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}