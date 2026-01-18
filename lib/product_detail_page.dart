import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'token_service.dart'; // Import baseUrl and getAccessToken
import 'cart_page.dart';

// --------------------------------------------------------------------------
// 1. Updated ProductDetailPage (Logic is retained)
// --------------------------------------------------------------------------

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  Map<String, dynamic>? _productData;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  // API Fetching, Add to Cart, Error/Popup helpers remain UNCHANGED (for brevity)

  Future<void> _fetchProductDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final url = Uri.parse('$baseUrl/products/${widget.productId}');
      final response = await http.get(url);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _productData = responseBody['data'];
          _isLoading = false;
        });
      } else {
        final responseBody = jsonDecode(response.body);
        setState(() {
          _error = responseBody['message'] ?? 'Failed to load product details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Product Detail Fetch Error: $e");
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addToCart() async {
    if (_productData == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adding item to cart...'), duration: Duration(seconds: 1)),
    );
    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) _showApiError('Authentication Error. Please log in.');
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
          "productId": widget.productId,
          "quantity": _quantity,
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

  void _showApiError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. Enhanced UI/Design Implementation
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Product Detail"), backgroundColor: Colors.white, elevation: 1,),
        body: Center(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center,)),
      );
    }

    // Safely extract data, including new fields
    final String name = _productData!['pname'] ?? 'Product Name';
    final double originalPrice = (_productData!['price'] ?? 0).toDouble();
    final int discount = _productData!['discount'] ?? 0;
    final double finalPrice = originalPrice * (1 - discount / 100);

    String imageUrl = _productData!['imageUrl'] ?? '';
    final String description = _productData!['description'] ?? 'No description available.';
    final String unit = _productData!['unit'] ?? 'pcs';
    final String brand = _productData!['brand'] ?? 'Unbranded';

    // Rating Extraction
    final Map<String, dynamic> ratings = _productData!['ratings'] ?? {'average': 0.0, 'count': 0};
    final double averageRating = (ratings['average'] ?? 0.0).toDouble();
    final int ratingCount = ratings['count'] ?? 0;

    // Localhost correction
    if (imageUrl.contains('localhost')) {
      imageUrl = imageUrl.replaceAll('http://localhost:8000', renderBaseUrl);
    } else if (imageUrl.contains('10.0.2.2')) {
      imageUrl = imageUrl.replaceAll('http://10.0.2.2:8000', renderBaseUrl);
    }

    return Scaffold(
      // App Bar (retained)
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      // Product Content
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Section (retained)
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 250,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      alignment: Alignment.center,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 80),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Product Details Section (Enhanced)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Brand & Ratings Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Tag
                      Text(
                        'Brand: $brand',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      // Ratings Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.star, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Price Row: Price, Discount, Unit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Final Price
                          Text(
                            '₹${finalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                          // Original Price (Strikethrough) and Discount
                          if (discount > 0)
                            Row(
                              children: [
                                Text(
                                  '₹${originalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$discount% OFF',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // Unit Tag (retained)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200)
                        ),
                        child: Text(
                          unit,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 30),

                  // Description Header (retained)
                  const Text(
                    "Product Description",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description Content (retained)
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ratings Summary (New Section)
                  if (ratingCount > 0)
                    Text(
                      'Rated ${averageRating.toStringAsFixed(1)} out of 5 from $ratingCount customer reviews.',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  const SizedBox(height: 20),


                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuantityButton(Icons.remove, () {
                        if (_quantity > 1) {
                          setState(() {
                            _quantity--;
                          });
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "$_quantity",
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                          ),
                        ),
                      ),
                      _buildQuantityButton(Icons.add, () {
                        setState(() {
                          _quantity++;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),

      // Add to Cart Button (Updated price calculation)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _addToCart, // Calls the API logic
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            "Add $_quantity to Cart - ₹${(finalPrice * _quantity).toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Helper widget for quantity buttons (retained)
  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.green, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  // Added to Cart Popup (retained)
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