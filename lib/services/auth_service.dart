import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../login.dart';

class AuthService {
  static Future<void> logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isAdmin', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  static Future<bool> verifyCode(String countryCode, String phone, String authCode) async {
    final response = await http.post(
      Uri.parse('https://droniem.lv/mtlqr/verify.php'),
      body: {
        'country_code': countryCode,
        'phone': phone,
        'auth_code': authCode,
      },
    );

    print(response.body);

    if (response.statusCode == 200) {
      var userData = jsonDecode(response.body); 
      if (userData['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        bool isAdmin = (userData['status_id'] != null && int.tryParse(userData['status_id'].toString()) == 2);
        String userUID = userData['uid'].toString();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isAdmin', isAdmin);
        await prefs.setString('userUID', userUID);

        return true; // Success
      } else {
        print('Error: ${userData['error']}');
        return false; // Failure
      }
    } else {
      print('Server error');
      return false; // Server error
    }
  }
}
