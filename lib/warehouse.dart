import 'services/config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'item_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Warehouse extends StatefulWidget {
  const Warehouse({super.key});

  @override
  WarehouseState createState() => WarehouseState();
}

class WarehouseState extends State<Warehouse> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  TextEditingController searchController = TextEditingController();
  bool _filterStatusAllItems = false;
  bool isLoading = false;

  static const Map<int, String> statusMap = {
    1: 'Noliktavā',
    2: 'Rezervēts',
    3: 'Izsniegts',
    4: 'Pazaudēts',
    5: 'Norakstīts',
  };

  String getStatusName(int? statusId) {
    return statusMap[statusId] ?? 'Nezināms';
  }

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterItems);
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
        Uri.parse(AppConfig.endpointDatabase),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_uid': userUID,
          'query': 'warehouse',
        }),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['command'] == 'logout') {
          if (!mounted) return;
          AuthService.logoutUser(context);
        } else {
          int userStatusId =
              int.tryParse(responseData['user_status_id'].toString()) ?? 0;
          AuthService.updateUserStatus(userStatusId);
          final List<dynamic> items = json.decode(responseData['items']);
          setState(() {
            _items = List<Map<String, dynamic>>.from(items);
            _filterItems();
          });
        }
      } else {
        throw Exception('Neizdevās iegūt priekšmetu sarakstu');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: $e'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterItems() {
    String query = searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        bool matchesSearch =
            item['code']?.toLowerCase().contains(query) ?? false;
        int? statusId = int.tryParse(item['status_id'].toString());
        if (_filterStatusAllItems) {
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
        automaticallyImplyLeading: false, // Noņem atpakaļbultiņu
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: searchController,
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
              icon: Icon(Icons.refresh),
              onPressed: fetchItems,
            ),
            // Filtra poga
            IconButton(
              icon: Icon(_filterStatusAllItems
                  ? Icons.filter_alt_off
                  : Icons.filter_alt),
              onPressed: () {
                setState(() {
                  _filterStatusAllItems = !_filterStatusAllItems;
                  _filterItems(); // Atsvaidzināt filtrus
                });
              },
            ),
            // Pievienot jaunu ierakstu
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
                          _filterItems(); // Atsvaidzināt filtrus
                        });
                        fetchItems(); // Atsvaidzināt priekšmetus no servera, ja nepieciešams
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
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
                    if (!_filterStatusAllItems)
                      const DataColumn(label: Text('Lietotājs')),
                    if (isLargeScreen) const DataColumn(label: Text('Statuss')),
                    const DataColumn(label: Text('Darbības')),
                  ],
                  rows: _filteredItems.map((item) {
                    int? statusId = int.tryParse(item['status_id'].toString());
                    bool? isDamaged = int.tryParse(item['damaged'].toString()) == 1;

                    Color? rowColor;
                    if (statusId == 2) {
                      rowColor = Colors.yellow.withValues(alpha: 0.3);
                    } else if (statusId == 3) {
                      rowColor = Colors.green.withValues(alpha: 0.3);
                    } else if ((statusId == 4 || statusId == 5) || isDamaged ) {
                      rowColor = Colors.red.withValues(alpha: 0.3);
                    }
                    return DataRow(
                      color: rowColor != null
                          ? WidgetStateProperty.all(rowColor)
                          : null,
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: 88), // Maksimālais platums
                            child: Text(
                              item['code'] ?? '',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),

                        if (!_filterStatusAllItems)
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 86),
                              child: Text(
                                item['name'] ?? '',
                                softWrap:
                                    true, // Atļauj tekstam aplauzties vairākās rindās
                                maxLines: 2, // Maksimums 2 rindas
                                overflow: TextOverflow
                                    .visible, // Atļauj parādīt visu 
                              ),
                            ),
                          ),
                        if (isLargeScreen) DataCell(Text(getStatusName(statusId))),
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
                                          int index = _items.indexWhere((i) =>
                                              i['uid'] == updatedItem['uid']);
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
