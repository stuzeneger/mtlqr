import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  final String phone;
  final String countryCode;

  VerificationScreen({required this.countryCode, required this.phone});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;

  // Funkcija, kas izsauc 'verifyCode' no PHP faila
  Future<void> verifyCode() async {
    setState(() {
      _loading = true;
    });

    // Izsauc AuthService verifyCode metodi
    bool success = await AuthService.verifyCode(
      widget.countryCode, 
      widget.phone, 
      _codeController.text,
    );

    setState(() {
      _loading = false;
    });

    if (success) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isAdmin = prefs.getBool('isAdmin') ?? false;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage(title: 'MTL', isAdmin: isAdmin)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Autorizācijas servisa kļūda!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ievadi SMS kodu")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Ievadi kodu'),
            ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: verifyCode,
                    child: Text("Apstiprināt"),
                  ),
          ],
        ),
      ),
    );
  }
}
