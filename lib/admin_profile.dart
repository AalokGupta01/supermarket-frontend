import 'dart:convert';
import 'dart:io'; // Required for File handling
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // Requires image_picker in pubspec.yaml
import 'package:intl/intl.dart'; // Add intl: ^0.18.0 to pubspec.yaml for date formatting
import 'token_service.dart';
import 'login.dart';
import 'package:http_parser/http_parser.dart'; // Required for MediaType

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Admin Profile Data
  String adminName = "Loading...";
  String adminEmail = "Loading...";
  bool _isLoadingProfile = true;

  // --- Product Controllers ---
  final _pNameController = TextEditingController();
  final _pPriceController = TextEditingController();
  final _pQuantityController = TextEditingController();

  // New Optional Controllers
  final _pBrandController = TextEditingController();
  final _pDescController = TextEditingController();
  final _pDiscountController = TextEditingController();
  final _pExpiryController = TextEditingController(); // Display text only

  DateTime? _selectedExpiryDate;

  // Image handling
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Selected Category
  String? _selectedCategory;

  final List<String> _categoryOptions = [
    "Bakery", "Dairy", "Beverages", "Vegetables", "Fruits",
    "Dry Fruits", "Snacks", "Grains & Pulses", "Frozen",
    "Household", "Personal care", "Others"
  ];

  @override
  void initState() {
    super.initState();
    _fetchAdminDetails();
  }

  @override
  void dispose() {
    _pNameController.dispose();
    _pPriceController.dispose();
    _pQuantityController.dispose();
    _pBrandController.dispose();
    _pDescController.dispose();
    _pDiscountController.dispose();
    _pExpiryController.dispose();
    super.dispose();
  }

  // --- API: Fetch Admin Profile ---
  Future<void> _fetchAdminDetails() async {
    try {
      final token = await getAccessToken();
      if (token == null) return;

      final url = Uri.parse('$baseUrl/admin/get-admin');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          adminName = data['fullName'] ?? data['username'] ?? "Admin";
          adminEmail = data['email'] ?? "";
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          adminName = "Error fetching";
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _isLoadingProfile = false);
    }
  }

  // --- Helper: Pick Image ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Please restart the app fully to enable image picker.")),
      );
    }
  }

  // --- Helper: Date Picker ---
  Future<void> _pickExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedExpiryDate) {
      setState(() {
        _selectedExpiryDate = picked;
        _pExpiryController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  // --- Helper: Upload Image ---
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final token = await getAccessToken();
      final uri = Uri.parse('$baseUrl/products/upload');

      var request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();

      // ---------------------------------------------------------
      // FIX: Determine MIME type explicitly
      // ---------------------------------------------------------
      String extension = imageFile.path.split('.').last.toLowerCase();
      MediaType contentType;

      if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (extension == 'gif') {
        contentType = MediaType('image', 'gif');
      } else {
        contentType = MediaType('image', 'jpeg'); // Default fallback
      }

      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: contentType, // <--- CRITICAL: Backend needs this to not see 'octet-stream'
      );

      request.files.add(multipartFile);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = jsonDecode(responseBody);
        return jsonResponse['data']?['url'] ?? jsonResponse['url'];
      } else {
        debugPrint("Upload failed: $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  // --- API: Add Product ---
  Future<void> _addProduct() async {
    // 1. Mandatory Validation
    if (_pNameController.text.isEmpty ||
        _pPriceController.text.isEmpty ||
        _pQuantityController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all mandatory fields (*)")),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a product image")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final token = await getAccessToken();

      // 2. Upload Image
      String? imageUrl = await _uploadImage(_selectedImage!);

      if (imageUrl == null) {
        throw Exception("Image upload failed. Cannot create product.");
      }

      // 3. Prepare Payload with Optional Fields
      final url = Uri.parse('$baseUrl/products');

      final Map<String, dynamic> payload = {
        "pname": _pNameController.text,
        "price": double.tryParse(_pPriceController.text) ?? 0,
        "quantity": double.tryParse(_pQuantityController.text) ?? 0,
        "category": _selectedCategory,
        "imageUrl": imageUrl,
        "available": double.tryParse(_pQuantityController.text) ?? 0,

        // Optional Fields
        "brand": _pBrandController.text.isNotEmpty ? _pBrandController.text : "generic",
        "description": _pDescController.text,
        "discount": double.tryParse(_pDiscountController.text) ?? 0,
        // Send date if selected
        if (_selectedExpiryDate != null)
          "expiryDate": _selectedExpiryDate!.toIso8601String(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final resData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product Added Successfully!")),
        );
        _clearProductFields();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resData['message'] ?? "Failed to add product")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _clearProductFields() {
    _pNameController.clear();
    _pPriceController.clear();
    _pQuantityController.clear();
    _pBrandController.clear();
    _pDescController.clear();
    _pDiscountController.clear();
    _pExpiryController.clear();
    setState(() {
      _selectedImage = null;
      _selectedCategory = null;
      _selectedExpiryDate = null;
    });
  }

  Future<void> _logout() async {
    await clearAccessToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

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
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isLoadingProfile
                  ? const CircularProgressIndicator()
                  : Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/profile.png'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Name : $adminName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    adminEmail,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---------------- Add Product Section ----------------
            const Text(
              'Add New Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // Mandatory Fields
            _buildTextField(
                controller: _pNameController,
                label: 'Product Name *',
                hint: 'e.g. Fresh Apple'
            ),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _pPriceController,
                      label: 'Price *',
                      hint: '150',
                      inputType: TextInputType.number
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                      controller: _pQuantityController,
                      label: 'Quantity *',
                      hint: 'e.g. 50',
                      inputType: TextInputType.number
                  ),
                ),
              ],
            ),

            // Category Dropdown
            const Text(
              'Category *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  hint: const Text("Select Category"),
                  items: _categoryOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Fields Header
            const Divider(),
            const Text(
              'Optional Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            _buildTextField(
                controller: _pBrandController,
                label: 'Brand',
                hint: 'e.g. Amul (Default: generic)'
            ),

            _buildTextField(
                controller: _pDescController,
                label: 'Description',
                hint: 'Product details...',
                maxLines: 3
            ),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      controller: _pDiscountController,
                      label: 'Discount (%)',
                      hint: '0',
                      inputType: TextInputType.number
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expiry Date',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _pExpiryController,
                        readOnly: true, // Prevent manual typing
                        onTap: _pickExpiryDate,
                        decoration: InputDecoration(
                          hintText: 'Select Date',
                          suffixIcon: const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        ),
                      ),
                      const SizedBox(height: 12), // Match spacing of _buildTextField
                    ],
                  ),
                ),
              ],
            ),

            const Divider(),
            const SizedBox(height: 10),

            // Image Picker Section
            const Text(
              'Product Image *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Tap to upload image", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save Product Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _addProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : const Text(
                  'Save Product',
                  style: TextStyle(
                      fontSize: 16,
                      color: Color.fromARGB(255, 247, 245, 245),
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 🔴 Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: inputType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}