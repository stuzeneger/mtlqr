import 'config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../login.dart';
import '../main.dart';

class AuthService {
  static Future<void> logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isAdmin', false);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  static Future<bool> verifyCode(BuildContext context, String countryCode, String phone, String authCode) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.endpointVerify),
        body: {
          'country_code': countryCode,
          'phone': phone,
          'auth_code': authCode,
        },
      );

      if (response.statusCode == 200) {
        var userData = jsonDecode(response.body);
        if (userData['status'] == 'success') {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String userUID = userData['uid'].toString();
          bool isAdmin = int.tryParse(userData['status_id'].toString()) == 2;
          await prefs.setBool('isLoggedIn', true);
          await prefs.setBool('isAdmin', isAdmin);
          await prefs.setString('userUID', userUID);
          return true; // Success
        } else {
          // ❌ Nepareizs kods - parādām paziņojumu un atgriežam lietotāju
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Nepareizs kods! Mēģini vēlreiz.")),
            );
            Navigator.pop(context); // Atgriežas iepriekšējā skatā
          }
          return false;
        }
      } else {
        // ❌ Servera kļūda
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kļūda serverī. Mēģini vēlreiz vēlāk.")),
          );
          Navigator.pop(context);
        }
        return false;
      }
    } catch (e) {
      // ❌ Neizdevās savienoties ar serveri
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Neizdevās izveidot savienojumu")),
        );
        Navigator.pop(context);
      }
      return false;
    }
  }

  static Future<void> updateUserStatus(int userStatusId) async {
    isAdminNotifier.value = userStatusId == 2;
  }
}
