import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'token_service.dart'; // Ensure this file has baseUrl, getAccessToken, and clearAccessToken
import 'home.dart';
import 'search_page.dart';
import 'order_page.dart';
import 'cart_page.dart';
import 'login.dart'; // Updated to match previous file name

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  bool _isLoading = true;
  String _error = '';

  // Controllers matching the backend model fields
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  // Controllers for password change
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  // --- API Handlers ---

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) _handleAuthError();
        return;
      }

      final url = Uri.parse('$baseUrl/users/current-user');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        fullNameController.text = data['fullName'] ?? '';
        emailController.text = data['email'] ?? '';
        usernameController.text = data['username'] ?? '';

        setState(() {
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // 401 Detected: Token invalid/expired
        _handleAuthError();
      } else {
        setState(() {
          _error = 'Failed to load profile. Status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Fetch User Error: $e");
      if (mounted) {
        setState(() {
          _error = 'Network error. Could not connect to server.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserData() async {
    final token = await getAccessToken();
    if (token == null) {
      _handleAuthError();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving profile...')),
    );

    try {
      final url = Uri.parse('$baseUrl/users/update-account');
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "fullName": fullNameController.text,
          "email": emailController.text,
          // "username": usernameController.text, // Uncomment if username is editable
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        setState(() {
          isEditing = false;
        });
      } else if (response.statusCode == 401) {
        // 401 Detected: Token invalid/expired
        _handleAuthError();
      } else {
        final responseBody = jsonDecode(response.body);
        _showApiError(responseBody['message'] ?? 'Failed to save profile.');
      }
    } catch (e) {
      if (kDebugMode) print("Update User Error: $e");
      if (mounted) _showApiError('Network error during save.');
    }
  }

  Future<void> _changePassword() async {
    final token = await getAccessToken();
    if (token == null) {
      _handleAuthError();
      return;
    }

    if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
      _showApiError('Please enter both old and new passwords.');
      return;
    }

    if (oldPasswordController.text == newPasswordController.text) {
      _showApiError('New password must be different from the old password.');
      return;
    }

    Navigator.of(context).pop(); // Close the dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changing password...')),
    );

    try {
      final url = Uri.parse('$baseUrl/users/change-password');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "oldPassword": oldPasswordController.text,
          "newPassword": newPasswordController.text,
        }),
      );

      oldPasswordController.clear();
      newPasswordController.clear();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        // 401 Detected: Token invalid/expired
        _handleAuthError();
      } else {
        final responseBody = jsonDecode(response.body);
        _showApiError(responseBody['message'] ?? 'Failed to change password.');
      }
    } catch (e) {
      if (kDebugMode) print("Password Change Error: $e");
      if (mounted) _showApiError('Network error during password change.');
    }
  }

  Future<void> _logout() async {
    final token = await getAccessToken();
    if (token == null) {
      _handleLogoutSuccess();
      return;
    }
    try {
      final url = Uri.parse('$baseUrl/users/logout');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // If logout fails with 401, the token is already invalid, so we proceed to local logout anyway
      if (response.statusCode == 401) {
        if (kDebugMode) print("Token expired during logout");
      }
    } catch (e) {
      if (kDebugMode) print("Logout Error: $e. Proceeding with local logout.");
    }
    if (mounted) {
      _handleLogoutSuccess();
    }
  }

  // --- UI/Helper Functions ---

  void _showApiError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Clears token and redirects to login
  void _handleAuthError() async {
    await clearAccessToken(); // From token_service.dart
    if (mounted) {
      // Show session expired message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please login again."),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _handleLogoutSuccess() async {
    await clearAccessToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showChangePasswordDialog() {
    oldPasswordController.clear();
    newPasswordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(labelText: "Current Password"),
              obscureText: true,
            ),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: "New Password"),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: const Text("My Profile"),
            backgroundColor: Colors.white,
            elevation: 0),
        body: Center(
            child: Text(_error,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("My Profile",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage("assets/profile.png"),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullNameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    usernameController.text,
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                  Text(
                    emailController.text,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isEditing) {
                        _saveUserData();
                      } else {
                        setState(() {
                          isEditing = true;
                        });
                      }
                    },
                    icon: Icon(isEditing ? Icons.save : Icons.edit, size: 18),
                    label: Text(isEditing ? "Save Changes" : "Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isEditing ? Colors.green.shade50 : Colors.white,
                      foregroundColor: isEditing ? Colors.green : Colors.black,
                      side: BorderSide(
                          color: isEditing ? Colors.green : Colors.grey),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Personal Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Account Details",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Updated fields based on model
            _buildTextField(
                "Full Name", fullNameController, TextInputType.name),
            _buildTextField(
                "Email Id", emailController, TextInputType.emailAddress),
            _buildTextField(
                "Username", usernameController, TextInputType.text,
                isUpdatable: false), // Username is unique/read-only

            const SizedBox(height: 16),

            // Password Change Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock, size: 18),
                label: const Text("Change Password"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.grey),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔴 Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _logout,
                child:
                const Text("Log Out →", style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // Bottom Navigation (Retained)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 4,
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
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyOrderPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: "Cart"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Order"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // Updated _buildTextField helper
  Widget _buildTextField(
      String label, TextEditingController controller, TextInputType keyboardType,
      {bool isUpdatable = true} // New parameter to control if a field is editable
      ) {
    bool enabled = isEditing && isUpdatable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(color: enabled ? Colors.black : Colors.grey.shade800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: enabled ? Colors.green : Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: enabled ? Colors.green : Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}