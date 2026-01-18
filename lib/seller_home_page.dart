import 'package:flutter/material.dart';
import 'seller_profile.dart';

class SellerHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selles"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellerProfilePage(),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundImage: AssetImage("assets/profile.png"),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Whole page scrollable
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Selles Overview",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "₹25,670",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text("Total Sales"),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "5",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text("Pending Orders"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),
                Text(
                  "Today's Order",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // Scrollable order list with fixed height
                SizedBox(
                  height: 300, // adjust height as needed
                  child: ListView(
                    children: [
                      orderTile("Ravi Kumar", "Completed", "₹1500"),
                      orderTile("Priya Sharma", "Pending", "₹850"),
                      orderTile("Amit Singh", "Completed", "₹3200"),
                      orderTile("Deepa Gupta", "Completed", "₹1200"),
                      orderTile("Jay Mer", "Completed", "₹2200"),
                      orderTile("Bhart Dsbhi", "Completed", "₹1600"),
                      // You can add more orders here...
                    ],
                  ),
                ),

                SizedBox(height: 20),
                Text(
                  "Print Bill",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // Print Bill section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Select Order",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            TextField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Customer Name",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            TextField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {},
                          child: Text(
                            "Print Bill",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.green,
                            textStyle: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom widget for order item
  Widget orderTile(String name, String status, String amount) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.shopping_cart),
        title: Text(name),
        subtitle: Text(status),
        trailing: Text(
          amount,
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
