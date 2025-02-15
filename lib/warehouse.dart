import 'dart:convert';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'item_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Warehouse extends StatefulWidget {
  @override
  _WarehouseState createState() => _WarehouseState();
}

class _WarehouseState extends State<Warehouse> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  TextEditingController _searchController = TextEditingController();
  bool _filterStatusLostItems = false;
  bool isLoading = false;

  static const Map<int, String> statusMap = {
    1: 'Noliktavā',
    2: 'Rezervēts',
    3: 'Izsniegts',
    4: 'Pazaudēts',
    5: 'Bojāts',
    6: 'Norakstīts',
  };

  String getStatusName(int? statusId) {
    return statusMap[statusId] ?? 'Nezināms';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchItems();
  }

  Future<void> fetchItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String userUID = prefs.getString('userUID') ?? '';

      final response = await http.post(
        Uri.parse('https://droniem.lv/mtlqr/warehouse.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_uid': userUID}),
      );
      print(response.body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData is Map<String, dynamic> && responseData['command'] == 'logout') {
          AuthService.logoutUser(context);
        } else if (responseData is List) {
          setState(() {
            _items = List<Map<String, dynamic>>.from(responseData);
            _filterItems();
          });
        }
      } else {
        throw Exception('Neizdevās iegūt priekšmetu sarakstu');
      }
    } catch (e) {
      print('Kļūda: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        bool matchesSearch = item['code']?.toLowerCase().contains(query) ?? false;
        int? statusId = int.tryParse(item['status_id'].toString());

        if (_filterStatusLostItems) {
          return matchesSearch && !(statusId == 3 || statusId == 2);
        } else {
          return matchesSearch && (statusId == 3 || statusId == 2);
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
              icon: Transform.rotate(
                angle: 3.1416,
                child: Icon(
                  _filterStatusLostItems ? Icons.filter_alt_off : Icons.filter_alt,
                  color: _filterStatusLostItems ? Colors.red : Colors.grey,
                ),
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchItems,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return ItemFormDialog(
                    onSubmit: (newItem) {
                      setState(() {
                        _items.add(newItem);
                        _filterItems();
                      });
                      fetchItems();
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Kods')),
                    if (!_filterStatusLostItems) const DataColumn(label: Text('Lietotājs')),
                    if (isLargeScreen) const DataColumn(label: Text('Statuss')),
                    const DataColumn(label: Text('Darbības')),
                  ],
                  rows: _filteredItems.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item['code'] ?? 'Nav')),
                        if (!_filterStatusLostItems) DataCell(Text(item['name'] ?? '')),
                        if (isLargeScreen) DataCell(Text(getStatusName(int.tryParse(item['status_id'].toString())))),
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


