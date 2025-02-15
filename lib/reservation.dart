import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Reservation extends StatefulWidget {
  @override
  _ReservationState createState() => _ReservationState();
}

class _ReservationState extends State<Reservation> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  TextEditingController _searchController = TextEditingController();
  bool isLoading = false;  // Jauns mainīgais, lai uzglabātu ielādes statusu

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchItems(); // Atjaunina datus katru reizi, kad skats tiek atvērts
  }

  // Centralizēta metode, kas iegūst lietotāja UID no SharedPreferences
  Future<String> _getUserUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userUID') ?? '';  // Atgriež tukšu virkni, ja nav atrasts
  }

  // Metode, kas iegūst datus no servera
  Future<void> fetchItems() async {
    setState(() {
      isLoading = true;  // Uzstājam ielādes statusu uz true
    });

    try {
      String userUID = await _getUserUID();  // Iegūstam userUID

      final url = Uri.parse('https://droniem.lv/mtlqr/warehouse.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_uid': userUID}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _items = List<Map<String, dynamic>>.from(responseData);
          _filterItems();
        });
      } else {
        throw Exception('Neizdevās iegūt priekšmetu sarakstu');
      }
    } catch (e) {
      print('Kļūda: $e');
    } finally {
      setState(() {
        isLoading = false;  // Kad dati ir iegūti vai gadījumā notikusi kļūda, ielāde ir pabeigta
      });
    }
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        return item['status_id'].toString() == '1' &&
               (item['code']?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  // Rezervēšanas metode
  Future<void> reserveItem(String itemUID) async {
    String userUID = await _getUserUID();  // Iegūstam userUID

    try {
      final response = await http.post(
        Uri.parse('https://droniem.lv/mtlqr/reserve.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_uid': userUID, 'item_uid': itemUID}),
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = _items.indexWhere((item) => item['uid'] == itemUID);
          if (index != -1) {
            _items[index]['status_id'] = '2';
          }
          _filterItems();
        });
      } else {
        throw Exception('Neizdevās rezervēt priekšmetu');
      }
    } catch (e) {
      print('Kļūda: $e');
    }
  }

  void _showReservationDialog(String itemUID) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apstiprinājums'),
          content: Text('Vai tiešām vēlaties rezervēt šo priekšmetu?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Atcelt'),
            ),
            TextButton(
              onPressed: () {
                reserveItem(itemUID);
                Navigator.of(context).pop();
              },
              child: Text('Apstiprināt'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Meklēt...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchItems,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())  // Rimbulītis tiek parādīts kamēr dati tiek ielādēti
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Code')),
                    const DataColumn(label: Text('Darbības')),
                  ],
                  rows: _filteredItems.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item['code'] ?? 'Nav')),
                        DataCell(
                          ElevatedButton(
                            onPressed: () => _showReservationDialog(item['uid']?.toString() ?? ''),
                            child: Text('Rezervēt'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }
}
