import 'package:flutter/material.dart';
import 'login.dart';

void main() {
  runApp(const SuperMarketApp());
}

class SuperMarketApp extends StatelessWidget {
  const SuperMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "SuperMarket",
      home: LoginPage(), // Start with LoginPage
    );
  }
}