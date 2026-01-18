import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'token_service.dart'; // IMPORTANT: Import the token service file

import 'product_list_page.dart';
import 'category_page.dart';
import 'all_product_page.dart';
import 'product_detail_page.dart';
import 'search_page.dart';
import 'cart_page.dart';
import 'order_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _popularProducts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPopularProducts();
  }

  /// Fetches products from the API
  Future<void> _fetchPopularProducts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Ensure baseUrl in token_service.dart is set to:
      // 'https://supermarket-back.onrender.com/api/v1'
      final url = Uri.parse('$baseUrl/products');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> productsData = responseBody['data'];

        setState(() {
          _popularProducts = List<Map<String, dynamic>>.from(productsData);
          _isLoading = false;
        });
      } else {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _error = responseBody['message'] ?? 'Failed to load products';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  // --- 🛒 Add to Cart API Logic ---
  Future<bool> _addToCart({
    required String productId,
    required int quantity,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) {
          _showApiError('Authentication Error. Please log in.');
        }
        return false;
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
          "quantity": quantity,
        }),
      );

      if (!mounted) return false;

      if (response.statusCode == 200) {
        return true;
      } else {
        // Handle API error messages
        final responseBody = jsonDecode(response.body);
        _showApiError(responseBody['message'] ?? 'Failed to add item to cart.');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("Add to Cart Error: $e");
      if (mounted) _showApiError('Network error. Could not connect to server.');
      return false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar remains unchanged
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Supermarket",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.person, color: Colors.black),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),

      // Scrollable Body (unchanged)
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Categories",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "See all",
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 🔹 Categories (horizontal scroll)
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    buildCategory(
                      "Dry Fruits",
                      "assets/category/Dry_fruite/main_logo.png",
                    ),
                    buildCategory(
                      "Bakery",
                      "assets/category/Bakery/main_logo.jpg",
                    ),
                    buildCategory(
                      "Beverages",
                      "assets/category/Beverages/main_logo.png",
                    ),
                    buildCategory(
                      "Snacks",
                      "assets/category/Snakes/main_logo.png",
                    ),
                    buildCategory(
                      "Grains & Pulses",
                      "assets/category/Grains_Pulses/main_logo.webp",
                    ),
                    buildCategory(
                      "Milk Product",
                      "assets/category/Dairy/main_logo.jpg",
                    ),
                    buildCategory(
                      "Vegetables",
                      "assets/category/Vegetables/main_logo.jpg",
                    ),
                    buildCategory(
                      "Fruits",
                      "assets/category/Fruite/main_logo.jpg",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Popular Products Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Popular Products",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllProductPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "See all",
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 🔹 Popular Products Grid (Dynamic)
              _buildPopularProductsGrid(),
            ],
          ),
        ),
      ),

      // Bottom Navigation remains unchanged
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
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

  // 🔹 Category Card
  Widget buildCategory(
      String title,
      String imagePath,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListPage(
              categoryName: title,
            ),
          ),
        );
      },
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset(
              imagePath,
              height: 80,
              width: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(title),
        ],
      ),
    );
  }

  /// Builds the grid for popular products, handling loading and error states
  Widget _buildPopularProductsGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(50.0),
          child: Text(
            _error,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_popularProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50.0),
          child: Text(
            "No products found.",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final productsToShow = _popularProducts;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: productsToShow
          .map((product) => buildProduct(product))
          .toList(),
    );
  }

  // 🔹 Product Card with Detail Navigation (updated button)
  Widget buildProduct(Map<String, dynamic> product) {
    final String productId = product['_id']; // Get the product ID
    final String name = product['pname'] ?? 'No Name';
    final String price = "₹${product['price'] ?? 0}";
    final String description = product['description'] ?? 'No description.';

    String imageUrl = product['imageUrl'] ?? '';

    // ----------------------------------------------------------------------
    // 🛠️ FIX: HANDLE RENDER vs LOCALHOST URLS
    // ----------------------------------------------------------------------
    // Your database might still have 'http://localhost:8000/...' or '10.0.2.2'.
    // We replace the domain part with your Render URL.

    // Note: Render uses https and typically maps port 80/443, not 8000 externally.


    if (imageUrl.contains('localhost')) {
      imageUrl = imageUrl.replaceAll('http://localhost:8000', renderBaseUrl);
    } else if (imageUrl.contains('10.0.2.2')) {
      imageUrl = imageUrl.replaceAll('http://10.0.2.2:8000', renderBaseUrl);
    }
    // ----------------------------------------------------------------------

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              productId: productId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: Image.network(
                imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    alignment: Alignment.center,
                    color: Colors.grey[200],
                    child: Icon(Icons.broken_image,
                        color: Colors.grey[600], size: 40),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(name,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                price,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                // 🚀 API call to add to cart
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adding item...'), duration: Duration(seconds: 1)),
                  );

                  final success = await _addToCart(
                    productId: productId,
                    quantity: 1, // Default quantity when adding from home screen
                  );

                  if (success) {
                    _showAddedPopup();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Add to Cart",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Added to Cart Popup
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
                          ); // Close popup
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