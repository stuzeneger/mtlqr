import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'dart:convert'; // Lai varētu izmantot jsonDecode


class VerificationScreen extends StatefulWidget {
  final String phone;

  VerificationScreen({required this.phone});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;

  Future<void> verifyCode() async {
    setState(() {
      _loading = true;
    });

    final response = await http.post(
      Uri.parse('https://droniem.lv/mtlqr/verify.php'),
      body: {'phone': widget.phone, 'code': _codeController.text},
    );


    setState(() {
      _loading = false;
    });

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body); 
      if (data['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        bool isAdmin = (data['status_id'] != null && int.tryParse(data['status_id'].toString()) == 2);
        String userUID = data['uid'].toString();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isAdmin', isAdmin);
        await prefs.setString('userUID', userUID);

        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage(title: 'MTL')),
      );

      }else {
      print('Error: ${data['error']}');
    }

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
