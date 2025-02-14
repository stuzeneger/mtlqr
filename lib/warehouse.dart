import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'item_form_dialog.dart';

class Warehouse extends StatefulWidget {
  @override
  _WarehouseState createState() => _WarehouseState();
}

class _WarehouseState extends State<Warehouse> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  TextEditingController _searchController = TextEditingController();
  bool _filterStatusLostItems = false; // Filtra stāvoklis

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
    fetchItems();
    _searchController.addListener(_filterItems);
  }

  Future<void> fetchItems() async {
    try {
      final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/warehouse.php'));

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
    }
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        bool matchesSearch = item['code']?.toLowerCase().contains(query) ?? false;
        int? status = int.tryParse(item['status_id'].toString());

        if (_filterStatusLostItems) {
          return matchesSearch && !(status == 3);
        } else {
          return matchesSearch && status == 3;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 600;

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
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _filterStatusLostItems ? Icons.filter_alt_off : Icons.filter_alt,
                color: _filterStatusLostItems ? Colors.red : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _filterStatusLostItems = !_filterStatusLostItems;
                  _filterItems();
                });
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Code')),
              if (isLargeScreen) const DataColumn(label: Text('QR Code')),
              const DataColumn(label: Text('Statuss')),
              const DataColumn(label: Text('Darbības')),
            ],
            rows: _filteredItems.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item['code'] ?? 'Nav')),
                  if (isLargeScreen) DataCell(Text(item['qr_code'] ?? 'Nav')),
                  DataCell(Text(getStatusName(int.tryParse(item['status_id'].toString()) ?? 0))),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ItemFormDialog(
                                item: item,
                                onSubmit: (updatedItem) {
                                  setState(() {
                                    int index = _items.indexWhere((i) => i['id'] == updatedItem['id']);
                                    if (index != -1) {
                                      _items[index] = updatedItem;
                                      _filterItems();
                                    }
                                  });
                                  fetchItems();
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}