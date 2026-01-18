import 'package:flutter/material.dart';
import 'package:super_market/login.dart';

class SellerProfilePage extends StatelessWidget {
  const SellerProfilePage({super.key});

  // Dummy order data
  final List<Map<String, dynamic>> orders = const [
    {
      "name": "Ravi Kumar",
      "status": "Completed",
      "amount": "₹1,500",
      "date": "2023-11-20",
    },
    {
      "name": "Priya Sharma",
      "status": "Pending",
      "amount": "₹850",
      "date": "2023-11-20",
    },
    {
      "name": "Amit Singh",
      "status": "Completed",
      "amount": "₹3,200",
      "date": "2023-11-20",
    },
    {
      "name": "Deepa Gupta",
      "status": "Completed",
      "amount": "₹1,200",
      "date": "2023-11-20",
    },
    {
      "name": "Pradip Kher",
      "status": "Pending",
      "amount": "₹950",
      "date": "2023-11-20",
    },
    {
      "name": "Manoj Soni",
      "status": "Completed",
      "amount": "₹2,100",
      "date": "2023-11-20",
    },
    {
      "name": "Sonal Patel",
      "status": "Completed",
      "amount": "₹1,800",
      "date": "2023-11-20",
    },
    {
      "name": "Vivek Mehta",
      "status": "Pending",
      "amount": "₹700",
      "date": "2023-11-20",
    },
    {
      "name": "Kiran Joshi",
      "status": "Completed",
      "amount": "₹2,500",
      "date": "2023-11-20",
    },
    {
      "name": "Meena Shah",
      "status": "Completed",
      "amount": "₹1,350",
      "date": "2023-11-20",
    },
    {
      "name": "Rohit Dubey",
      "status": "Pending",
      "amount": "₹600",
      "date": "2023-11-20",
    },
    {
      "name": "Nisha Thakur",
      "status": "Completed",
      "amount": "₹4,000",
      "date": "2023-11-20",
    },
    {
      "name": "Ajay Yadav",
      "status": "Completed",
      "amount": "₹2,200",
      "date": "2023-11-20",
    },
    {
      "name": "Sita Verma",
      "status": "Pending",
      "amount": "₹750",
      "date": "2023-11-20",
    },
    {
      "name": "Harsh Malhotra",
      "status": "Completed",
      "amount": "₹1,950",
      "date": "2023-11-20",
    },
    {
      "name": "Renu Bhatia",
      "status": "Completed",
      "amount": "₹3,000",
      "date": "2023-11-20",
    },
    {
      "name": "Suresh Choudhary",
      "status": "Pending",
      "amount": "₹880",
      "date": "2023-11-20",
    },
    {
      "name": "Anita Goyal",
      "status": "Completed",
      "amount": "₹2,700",
      "date": "2023-11-20",
    },
    {
      "name": "Raj Malviya",
      "status": "Completed",
      "amount": "₹1,600",
      "date": "2023-11-20",
    },
    {
      "name": "Pooja Jain",
      "status": "Pending",
      "amount": "₹950",
      "date": "2023-11-20",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          // Profile Card
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: const [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage("assets/profile.png"),
                ),
                SizedBox(height: 10),
                Text(
                  "Name : Rajveer Rajput",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "rravjeer555@gmail.com",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Orders Section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                const Text(
                  "All Order That You Managed",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Order Cards
                for (var order in orders)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 30,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order["name"],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  order["date"],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              order["status"],
                              style: TextStyle(
                                color: order["status"] == "Completed"
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              order["amount"],
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 70), // space before logout button
              ],
            ),
          ),
        ],
      ),

      // Logout Button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          child: const Text("Log Out →", style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
