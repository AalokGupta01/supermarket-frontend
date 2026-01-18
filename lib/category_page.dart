import 'package:flutter/material.dart';
import 'product_list_page.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  static Widget buildCategory(
      String title,
      String imagePath,
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: () {
        // Navigate to the ProductListPage with the selected category name
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
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Categories",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                children: [
                  buildCategory(
                    "Dry Fruits",
                    "assets/category/Dry_fruite/main_logo.png",
                    context,
                  ),
                  buildCategory(
                    "Bakery",
                    "assets/category/Bakery/main_logo.jpg",
                    context,
                  ),
                  buildCategory(
                    "Beverages",
                    "assets/category/Beverages/main_logo.png",
                    context,
                  ),
                  buildCategory(
                    "Grains & Pulses",
                    "assets/category/Grains_Pulses/main_logo.webp",
                    context,
                  ),
                  buildCategory(
                    "Snacks",
                    "assets/category/Snakes/main_logo.png",
                    context,
                  ),
                  buildCategory(
                    "Milk Product",
                    "assets/category/Dairy/main_logo.jpg",
                    context,
                  ),
                  buildCategory(
                    "Vegetables",
                    "assets/category/Vegetables/main_logo.jpg",
                    context,
                  ),
                  buildCategory(
                    "Fruits",
                    "assets/category/Fruite/main_logo.jpg",
                    context,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}