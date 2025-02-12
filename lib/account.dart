import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MyAccountScreen extends StatefulWidget {
  @override
  _MyAccountScreenState createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  Map<String, dynamic>? userData; 

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {   
      


     SharedPreferences prefs = await SharedPreferences.getInstance();
      String userUID = prefs.getString('userUID') ?? '';
print(userUID);

      final response = await http.get(
        Uri.parse('https://droniem.lv/mtlqr/get_user.php')
            .replace(queryParameters: {
          'uid': userUID,
        }),
      );
 
print(response);
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
                  Text("Tālrunis: +${userData!['phone']}", style: TextStyle(fontSize: 18)),
                  Text("Statuss: ${userData!['status']}", style: TextStyle(fontSize: 18)),
                  Text("Reģistrēts: ${userData!['registered']}", style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
    );
  }
}
