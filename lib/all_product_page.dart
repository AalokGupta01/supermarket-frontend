import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'product_detail_page.dart';
import 'search_page.dart';
import 'cart_page.dart';
import 'order_page.dart';
import 'profile_page.dart';
import 'token_service.dart'; // Import baseUrl and getAccessToken

class AllProductPage extends StatefulWidget {
  const AllProductPage({super.key});

  @override
  State<AllProductPage> createState() => _AllProductPageState();
}

class _AllProductPageState extends State<AllProductPage> {
  List<dynamic> _allProducts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
  }

  // --------------------------------------------------------------------------
  // 1. API Fetching Logic (getAllProducts)
  // --------------------------------------------------------------------------

  Future<void> _fetchAllProducts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Endpoint: GET /api/v1/products (No parameters needed to get all)
      final url = Uri.parse('$baseUrl/products');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        setState(() {
          // Assuming 'data' contains the list of products
          _allProducts = responseBody['data'];
          _isLoading = false;
        });
      } else {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _error = responseBody['message'] ?? 'Failed to load products.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("All Products Fetch Error: $e");
      }
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // 2. Add to Cart Logic
  // --------------------------------------------------------------------------

  Future<void> _addToCart({required String productId}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adding item to cart...'), duration: Duration(milliseconds: 800)),
    );

    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) {
          _showApiError('Authentication Error. Please log in.');
        }
        return;
      }

      final url = Uri.parse('$baseUrl/cart/add');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "productId": productId,
          "quantity": 1, // Default to 1 when adding from the list view
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showAddedPopup();
      } else {
        final responseBody = jsonDecode(response.body);
        _showApiError(responseBody['message'] ?? 'Failed to add item to cart.');
      }
    } catch (e) {
      if (kDebugMode) print("Add to Cart Error: $e");
      if (mounted) _showApiError('Network error. Could not connect to server.');
    }
  }

  // Helper to show errors using SnackBar
  void _showApiError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. UI Build Method
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error.isNotEmpty) {
      bodyContent = Center(
        child: Text(
          _error,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    } else if (_allProducts.isEmpty) {
      bodyContent = const Center(
        child: Text("No products available at the moment.", style: TextStyle(fontSize: 16)),
      );
    } else {
      bodyContent = Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: _allProducts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (context, index) {
            final product = _allProducts[index];
            return _buildProductGridItem(product);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "All Product",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bodyContent,
      // Bottom Navigation (Retained)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          // Navigation logic remains the same
          if (index == 0) {
            // Already on Home
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyOrderPage()),
            );
          } else if (index == 4) {
            Navigator.push(
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
    );
  }

  // --------------------------------------------------------------------------
  // 4. Product Grid Item Widget (Updated to use network data)
  // --------------------------------------------------------------------------

  Widget _buildProductGridItem(Map<String, dynamic> product) {
    final String productId = product['_id'] ?? 'default_id';
    final String name = product['pname'] ?? 'Product Name';
    final double price = (product['price'] ?? 0).toDouble();
    String imageUrl = product['imageUrl'] ?? '';

    // Fix for localhost (Android Emulator)
    if (imageUrl.contains('localhost')) {
      imageUrl = imageUrl.replaceAll('http://localhost:8000', renderBaseUrl);
    } else if (imageUrl.contains('10.0.2.2')) {
      imageUrl = imageUrl.replaceAll('http://10.0.2.2:8000', renderBaseUrl);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              productId: productId, // Pass the API-provided ID
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image (Network)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Image.network(
                imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image,
                        color: Colors.grey, size: 40),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Text(
                name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '₹${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _addToCart(productId: productId), // Call API Add to Cart
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Add to Cart",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. Popup message (Retained)
  // --------------------------------------------------------------------------

  void _showAddedPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    const Image(
                      image: AssetImage('assets/Check_mark.png'),
                      height: 100,
                      width: 100,
                    ),
                    const SizedBox(height: 15),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "Item ",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: "added to the cart",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "View Cart",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.black54,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}