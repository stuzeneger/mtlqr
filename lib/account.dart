import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MyAccountScreen extends StatefulWidget {
  @override
  _MyAccountScreenState createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  Map<String, dynamic>? userData; // Lietotāja dati

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse('https://droniem.lv/mtlqr/get_user.php?uid=fd508503-cc0b-4c43-8eaf-56c0bcbbd170'), // Maini URL!
      );

      if (response.statusCode == 200) {
        setState(() {
          userData = json.decode(response.body);
        });
      } else {
        throw Exception("Kļūda API pieprasījumā: ${response.statusCode}");
      }
    } catch (e) {
      print("Neizdevās iegūt datus: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mans konts"),
      ),
      body: userData == null
          ? const Center(child: CircularProgressIndicator()) // Ja dati vēl nav, rādīt loaderi
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Vārds: ${userData!['name']}", style: TextStyle(fontSize: 20)),
                  Text("Telefons: ${userData!['phone']}", style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
    );
  }
}
