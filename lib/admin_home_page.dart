import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml for formatting
import 'token_service.dart';
import 'admin_profile.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int selectedTab = 0; // 0 = Product, 1 = Category, 2 = Orders
  bool isLoading = false;

  // Dynamic Data Lists
  List<dynamic> products = [];
  List<dynamic> categories = [];
  List<dynamic> orders = []; // Changed from sellers to orders

  @override
  void initState() {
    super.initState();
    _fetchDataForTab(selectedTab);
  }

  // Central function to fetch data based on current tab
  Future<void> _fetchDataForTab(int tabIndex) async {
    setState(() => isLoading = true);
    try {
      if (tabIndex == 0) {
        await _fetchProducts();
      } else if (tabIndex == 1) {
        await _fetchCategories();
      } else if (tabIndex == 2) {
        await _fetchOrders(); // Fetch Orders instead of Sellers
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- API CALLS ---

  Future<void> _fetchProducts() async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl/products');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      setState(() {
        products = jsonResponse['data'];
      });
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<void> _fetchCategories() async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl/admin/categories');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      setState(() {
        categories = jsonResponse['data'];
      });
    } else {
      throw Exception('Failed to load categories');
    }
  }

  // New: Fetch All Orders
  Future<void> _fetchOrders() async {
    final token = await getAccessToken();
    // Ensure you added this route to admin.routes.js
    final url = Uri.parse('$baseUrl/admin/orders');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      setState(() {
        orders = jsonResponse['data'];
      });
    } else {
      throw Exception('Failed to load orders');
    }
  }

  // New: Update Order Status
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl/admin/orders/$orderId/status');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order marked as $newStatus")),
        );
        _fetchOrders(); // Refresh list
      } else {
        throw Exception("Failed to update status");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // --- DELETE ACTIONS ---

  Future<void> _deleteProduct(String id) async {
    final token = await getAccessToken();
    final url = Uri.parse('$baseUrl/products/$id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        _fetchProducts(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Admin Management",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: const CircleAvatar(
                backgroundImage: AssetImage("assets/profile.png"),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTab("Product", 0),
                _buildTab("Category", 1),
                _buildTab("Orders", 2), // Renamed from Seller
              ],
            ),
            const SizedBox(height: 20),

            // Selected tab content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab builder
  Widget _buildTab(String text, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.green : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.black,
            side: const BorderSide(color: Colors.green),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () {
            setState(() {
              selectedTab = index;
            });
            _fetchDataForTab(index);
          },
          child: Text(text),
        ),
      ),
    );
  }

  // Content based on selected tab
  Widget _buildTabContent() {
    if (selectedTab == 0) {
      return _buildProductTable();
    } else if (selectedTab == 1) {
      return _buildCategoryTable();
    } else {
      return _buildOrderList(); // Renamed from SellerList
    }
  }

  // ----------------- Product Table -----------------
  Widget _buildProductTable() {
    if (products.isEmpty) {
      return const Center(child: Text("No products found"));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Table(
        border: TableBorder.all(color: Colors.grey, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(1.8),
          3: FlexColumnWidth(2.2),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Colors.grey),
            children: [
              _HeaderCell("Name"),
              _HeaderCell("Price"),
              _HeaderCell("Stock"),
              _HeaderCell("Actions"),
            ],
          ),
          for (var product in products)
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _DataCell(product["pname"] ?? "N/A"),
                _DataCell("₹${product["price"]}"),
                _DataCell("${product["quantity"]}"),
                _ActionCell(
                  onEdit: () {},
                  onDelete: () {
                    _deleteProduct(product["_id"]);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ----------------- Category Table -----------------
  Widget _buildCategoryTable() {
    if (categories.isEmpty) {
      return const Center(child: Text("No categories found"));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Table(
        border: TableBorder.all(color: Colors.grey, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(3),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Colors.grey),
            children: [
              _HeaderCell("Name"),
              _HeaderCell("Varieties"),
              _HeaderCell("Restock"),
            ],
          ),
          for (var category in categories)
            TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _DataCell(category["name"] ?? "N/A"),
                _DataCell("${category["varieties"]}"),
                _DataCell(category["restock"] ?? "Weekly"),
              ],
            ),
        ],
      ),
    );
  }

  // ----------------- Order List (Replaces Seller List) -----------------
  Widget _buildOrderList() {
    if (orders.isEmpty) {
      return const Center(child: Text("No orders found"));
    }
    return ListView.builder(
      itemCount: orders.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final order = orders[index];
        final user = order['user'] ?? {};
        final items = order['items'] as List<dynamic>? ?? [];
        final String status = order['orderStatus'] ?? 'Pending';
        final String orderId = order['_id'] ?? 'Unknown';

        // Helper to format date
        String formattedDate = "N/A";
        if (order['createdAt'] != null) {
          try {
            // You can add intl package for DateFormat or use substring
            formattedDate = order['createdAt'].toString().substring(0, 10);
          } catch (e) {}
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order ID and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Order #${orderId.substring(orderId.length - 6)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(),

                // Customer Details
                Text("Customer: ${user['username'] ?? 'Unknown User'}"),
                Text("Email: ${user['email'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),

                const SizedBox(height: 8),

                // Items Summary
                Text(
                  "${items.length} Items • Total: ₹${order['totalAmount']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),

                const SizedBox(height: 10),

                // Status Management
                Row(
                  children: [
                    const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: status,
                          isDense: true,
                          items: ["Pending", "Shipped", "Delivered", "Cancelled"]
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null && newStatus != status) {
                              _updateOrderStatus(orderId, newStatus);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------- Reusable Widgets -----------------
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  const _DataCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ActionCell({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black, size: 20),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}