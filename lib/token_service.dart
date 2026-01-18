import 'package:shared_preferences/shared_preferences.dart';

// Use the correct base URL based on your development environment
const String baseUrl = 'https://supermarket-back.onrender.com/api/v1';
// const String baseUrl = 'http://10.72.127.12:8000/api/v1';
const String renderBaseUrl = 'https://supermarket-back.onrender.com';
// const String renderBaseUrl = 'http://10.72.127.12:8000';

// Key used to store the JWT token
const String _tokenKey = 'accessToken';

Future<String?> getAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_tokenKey);
}

// Example: Function to save the token after successful login
Future<void> saveAccessToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tokenKey, token);
}

// Example: Function to clear the token on logout
Future<void> clearAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_tokenKey);
}