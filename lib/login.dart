import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'authorize.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = "+371"; // Noklusējuma valsts kods
  bool _loading = false;

  final List<String> countryCodes = ["+371", "+370", "+372", "+49", "+44", "+1"]; // Pievieno vajadzīgos kodus

  Future<void> sendPhoneNumber() async {
    String countryCode = _selectedCountryCode.replaceFirst('+', '');
    String phoneNumber = _phoneController.text;
      

    setState(() {
      _loading = true;
    });

    print('Sūtu SMS');

    final response = await http.get(
      Uri.parse('https://droniem.lv/mtlqr/authorize.php').replace(
        queryParameters: {'country_code': countryCode, 'phone': phoneNumber},
      ),
    );

    setState(() {
      _loading = false;
    });

print(response.body);

    if (response.statusCode == 200) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(countryCode: countryCode, phone: phoneNumber),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neizdevās nosūtīt SMS')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Autorizācija")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                // Valsts koda izvēlne
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCountryCode,
                    decoration: InputDecoration(labelText: 'Valsts kods'),
                    items: countryCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(code),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountryCode = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Telefona numura ievades lauks
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'Mobilā tālruņa numurs'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Tikai cipari
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: sendPhoneNumber,
                    child: Text("Saņemt SMS kodu"),
                  ),
          ],
        ),
      ),
    );
  }
}
