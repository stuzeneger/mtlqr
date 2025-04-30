import 'services/config.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/event.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key}); // Pievienots super parameter 'key'

  @override
  MyAccountScreenState createState() => MyAccountScreenState();
}

class MyAccountScreenState extends State<MyAccountScreen> {
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
      final response = await http.post(
        Uri.parse(AppConfig.endpointRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_uid': userUID,
          'event': Events.getUser.name,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);        
        if (responseData is Map<String, dynamic> && responseData.containsKey('result')) {
          setState(() {
            userData = responseData['result'];
          });
        } else {
          throw Exception("Nederīga API atbilde");
        }
      } else {
        throw Exception("Kļūda API pieprasījumā: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Neizdevās iegūt datus: $e");
    }
  }

  String getUserStatusName(String? statusId) {
    int? statusInt = int.tryParse(statusId ?? '');
    switch (statusInt) {
      case 1:
        return 'Lietotājs';
      case 2:
        return 'Pārzinis';
      case 3:
        return 'Bloķēts';
      case 0:
        return 'Ielūgts';
      default:
        return 'Nepazīstams statuss';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mans konts"),
      ),
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Vārds: ${userData?['name'] ?? 'Nezināms'}", style: const TextStyle(fontSize: 20)),
                  Text("Tālrunis: +${userData?['phone'] ?? 'Nezināms'}", style: const TextStyle(fontSize: 18)),
                  Text("Statuss: ${getUserStatusName(userData?['status_id'])}", style: const TextStyle(fontSize: 18)),
                  Text("Reģistrēts: ${userData?['registered'] ?? 'Nezināms'}", style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
    );
  }
}
