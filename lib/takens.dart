import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Takens extends StatefulWidget {
  const Takens({Key? key}) : super(key: key);

  @override
  _TakenState createState() => _TakenState();
}

class _TakenState extends State<Takens> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // Funkcija, lai iegūtu datus no servera
  Future<void> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? ''; // Saņem lietotāja UID no SharedPreferences

    final response = await http.post(
      Uri.parse('https://droniem.lv/mtlqr/takens.php'), // Pareizais PHP URL
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_uid': userUID, // Pievieno lietotāja UID
      }),
    );

    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body); // Pārveido atbildi kā sarakstu

      if (data.isNotEmpty) { // Ja saraksts nav tukšs
        setState(() {
          _data = List<Map<String, dynamic>>.from(data);
        });
      } else {
        setState(() {
          _data = [];
        });
      }
    } else {
      throw Exception('Neizdevās iegūt datus');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Noņemts appBar ar virsrakstu
      body: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Kods')),
            DataColumn(label: Text('Datums')),
          ],
          rows: _data.map((item) {
            return DataRow(cells: [
              DataCell(Text(item['code'] ?? 'Nav')),
              DataCell(Text(item['date'] ?? 'Nav')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
