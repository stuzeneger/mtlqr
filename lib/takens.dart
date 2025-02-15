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
  bool isLoading = false;  // Jauns mainīgais, lai pārvaldītu ielādes statusu

  static const Map<int, String> statusMap = {
    1: 'Noliktavā',
    2: 'Rezervēts',
    3: 'Izsniegts',
    4: 'Pazaudēts',
    5: 'Bojāts',
    6: 'Norakstīts',
  };

  String getStatusName(int statusId) {
    return statusMap[statusId] ?? 'Nezināms';
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;  // Uzstādam ielādes statusu uz true
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';

    final response = await http.post(
      Uri.parse('https://droniem.lv/mtlqr/takens.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_uid': userUID,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _data = List<Map<String, dynamic>>.from(data);
        isLoading = false;  // Ielāde pabeigta, mainām statusu
      });
    } else {
      setState(() {
        isLoading = false;  // Ielādes kļūda, arī jānomaina uz false
      });
      throw Exception('Neizdevās iegūt datus');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),  // Noņemts virstaksts
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())  // Parādām rimbulīti, kamēr tiek ielādēti dati
          : SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kods')),
                  DataColumn(label: Text('Statuss')),
                  DataColumn(label: Text('Datums')),
                ],
                rows: _data.map((item) {
                  return DataRow(cells: [
                    DataCell(Text(item['code'] ?? 'Nav')),
                    DataCell(Text(getStatusName(int.tryParse(item['status_id'].toString()) ?? 0))),
                    DataCell(Text(item['date'] ?? 'Nav')),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}
