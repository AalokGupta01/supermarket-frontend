import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// Assuming you have defined baseUrl and getAccessToken in token_service.dart
import 'token_service.dart';
import 'order_page.dart';
import 'home.dart';
import 'search_page.dart';
import 'payment_method_page.dart'; // Contains PaymentPage widget
import 'profile_page.dart';

// --------------------------------------------------------------------------
// 🎯 DATA MODELS
// --------------------------------------------------------------------------

/// Represents the final delivery address structure used for the order.
class DeliveryAddress {
  final String recipientName;
  final String mobileNumber;
  final String streetAddress;
  final String? apartment;
  final String city;
  final String postalCode;

  DeliveryAddress({
    required this.recipientName,
    required this.mobileNumber,
    required this.streetAddress,
    this.apartment,
    required this.city,
    required this.postalCode,
  });
}

// --------------------------------------------------------------------------
// 📦 SAVED ADDRESS MODEL (Used for fetching and showing list of addresses)
// --------------------------------------------------------------------------

class Address {
  final String id;
  final String recipientName;
  final String mobileNumber;
  final String streetAddress;
  final String? apartment;
  final String city;
  final String postalCode;

  Address({
    required this.id,
    required this.recipientName,
    required this.mobileNumber,
    required this.streetAddress,
    this.apartment,
    required this.city,
    required this.postalCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] ?? json['id'] ?? '',
      recipientName: json['recipientName'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      streetAddress: json['streetAddress'] ?? '',
      apartment: json['apartment'],
      city: json['city'] ?? '',
      postalCode: json['postalCode'] ?? '',
    );
  }
}


class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  // 1. Controllers for all form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  // 2. State management
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;
  bool _saveForFuture = false;
  bool _isLoading = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchSavedAddresses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // --- API Handlers ---

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _fetchSavedAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await getAccessToken();
      if (token == null) return;

      final url = Uri.parse('$baseUrl/address/all');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List data = responseBody['data'] ?? [];

        setState(() {
          _savedAddresses = data.map((item) => Address.fromJson(item)).toList();
          _isLoading = false;
          if (_savedAddresses.isNotEmpty) {
            _selectAddress(_savedAddresses.first);
          }
        });
      } else {
        _showSnackBar('Failed to load saved addresses. Status: ${response.statusCode}');
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (kDebugMode) print("Fetch Address Error: $e");
      if (mounted) {
        _showSnackBar('Network error while fetching addresses.');
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _submitAddress(bool shouldSave) async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields correctly.');
      return;
    }

    // --------------------------------------------------------------------------
    // 1. ASSEMBLE DELIVERY ADDRESS OBJECT (from the current form data)
    // --------------------------------------------------------------------------
    final deliveryAddress = DeliveryAddress(
      recipientName: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      streetAddress: _streetController.text.trim(),
      apartment: _apartmentController.text.trim().isEmpty ? null : _apartmentController.text.trim(),
      city: _cityController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
    );

    // NOTE: Cart emptiness check has been intentionally removed from this page.
    // The check is now performed in PaymentPage or on the backend.

    // --------------------------------------------------------------------------
    // 2. OPTIONAL: SAVE ADDRESS LOGIC
    // --------------------------------------------------------------------------
    if (shouldSave) {
      _showSnackBar('Saving address...', color: Colors.blue);

      final addressData = {
        "recipientName": deliveryAddress.recipientName,
        "mobileNumber": deliveryAddress.mobileNumber,
        "streetAddress": deliveryAddress.streetAddress,
        "apartment": deliveryAddress.apartment,
        "city": deliveryAddress.city,
        "postalCode": deliveryAddress.postalCode,
        "isDefault": _saveForFuture, // This uses the checkbox state
      };

      try {
        final token = await getAccessToken();
        if (token == null) return;

        final url = Uri.parse('$baseUrl/address/save');
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(addressData),
        );

        if (!mounted) return;

        if (response.statusCode == 201) {
          _showSnackBar('Address saved successfully!', color: Colors.green);
          _fetchSavedAddresses(); // Refresh list
        } else {
          final responseBody = jsonDecode(response.body);
          _showSnackBar(responseBody['message'] ?? 'Failed to save address.');
        }
      } catch (e) {
        if (kDebugMode) print("Submit Address Error: $e");
        if (mounted) _showSnackBar('Network error during submission.');
      }
    }

    // --------------------------------------------------------------------------
    // 3. NAVIGATE TO PAYMENT PAGE
    // --------------------------------------------------------------------------
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          deliveryAddress: deliveryAddress, // Pass the DeliveryAddress
        ),
      ),
    );
  }

  void _selectAddress(Address address) {
    setState(() {
      _selectedAddress = address;
      // Populate form fields with selected address data
      _nameController.text = address.recipientName;
      _mobileController.text = address.mobileNumber;
      _streetController.text = address.streetAddress;
      _apartmentController.text = address.apartment ?? '';
      _cityController.text = address.city;
      _postalCodeController.text = address.postalCode;
    });
  }

  // --- UI Helpers ---

  Widget _buildLabeledField(
      String label,
      TextEditingController controller,
      String hint, {
        TextInputType inputType = TextInputType.text,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSavedAddressCard(Address address) {
    final isSelected = _selectedAddress?.id == address.id;
    return InkWell(
      onTap: () => _selectAddress(address),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.green.shade50 : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              address.recipientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${address.streetAddress}, ${address.apartment != null && address.apartment!.isNotEmpty ? '${address.apartment}, ' : ''}${address.city} - ${address.postalCode}',
            ),
            Text(
              'Mobile: ${address.mobileNumber}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Delivery Address",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Delivery Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Saved Addresses Section
              if (_savedAddresses.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Saved Addresses",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _savedAddresses.length,
                        itemBuilder: (context, index) {
                          return _buildSavedAddressCard(_savedAddresses[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      "or Enter a New Address",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),


              // Contact Details
              const Text(
                "Contact Details",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _buildLabeledField(
                "Full Name",
                _nameController,
                "Enter Your Name",
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              _buildLabeledField(
                "Mobile No.",
                _mobileController,
                "Enter Your Mobile No.",
                inputType: TextInputType.phone,
                validator: (v) => v!.length < 10 ? 'Enter a valid mobile number' : null,
              ),

              const SizedBox(height: 20),

              // Address Details
              const Text(
                "Address Details",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _buildLabeledField(
                "Enter your address (Street/Locality)",
                _streetController,
                "Enter Your Street Address",
                validator: (v) => v!.isEmpty ? 'Street address is required' : null,
              ),
              const SizedBox(height: 14),
              _buildLabeledField(
                "Apartment/Suite/Building (Optional)",
                _apartmentController,
                "Apt No. / Building Name",
              ),
              const SizedBox(height: 14),

              // Row with City + Postal Code
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      "City",
                      _cityController,
                      "City Name",
                      validator: (v) => v!.isEmpty ? 'City is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      "Postal Code",
                      _postalCodeController,
                      "XXXXXX",
                      inputType: TextInputType.number,
                      validator: (v) => v!.length != 6 ? '6-digit code required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Checkbox to save the address
              Row(
                children: [
                  Checkbox(
                    value: _saveForFuture,
                    onChanged: (value) {
                      setState(() {
                        _saveForFuture = value ?? false;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                  const Expanded(child: Text("Save address for future use.")),
                ],
              ),
              const SizedBox(height: 20),

              // Continue Payment Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submitAddress(_saveForFuture),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Continue Payment",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 2, // Cart tab
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
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: "Order"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}