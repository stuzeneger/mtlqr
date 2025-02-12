import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Reservation extends StatefulWidget {
  const Reservation({Key? key}) : super(key: key);

  @override
  State<Reservation> createState() => _ReservationState();
}

class _ReservationState extends State<Reservation> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/get_items.php'));
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _data = List<Map<String, dynamic>>.from(responseData);
        });
      } else {
        throw Exception('Neizdevās iegūt datus');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kļūda: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervācijas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kods')),
                  DataColumn(label: Text('Veids')),
                  DataColumn(label: Text('Statuss')),
                  DataColumn(label: Text('Datums')),
                ],
                rows: _data.map((item) {
                  return DataRow(cells: [
                    DataCell(Text(item['code'] ?? 'Nav')),
                    DataCell(Text(item['type'] ?? 'Nav')),
                    DataCell(Text(item['status_id'] ?? 'Nav')),
                    DataCell(Text(item['date'] ?? 'Nav')),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}
