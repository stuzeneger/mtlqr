import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Taken extends StatefulWidget {
  const Taken({Key? key}) : super(key: key);

  @override
  _TakenState createState() => _TakenState();
}

class _TakenState extends State<Taken> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/get_items.php'));
    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      setState(() {
        _data = List<Map<String, dynamic>>.from(responseData);
      });
    } else {
      throw Exception('Neizdevās iegūt datus');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Kods')),
          DataColumn(label: Text('Veids')),
          DataColumn(label: Text('Statuss')),
        ],
        rows: _data.map((item) {
          return DataRow(cells: [
            DataCell(Text(item['code'] ?? 'Nav')),
            DataCell(Text(item['type'] ?? 'Nav')),
            DataCell(Text(item['status_id'] ?? 'Nav')),
          ]);
        }).toList(),
      ),
    );
  }
}
