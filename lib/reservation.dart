import 'services/config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'services/auth_service.dart';
import 'models/event.dart';

class Reservation extends StatefulWidget {
  const Reservation({super.key});

  @override
  ReservationState createState() => ReservationState();
}

class ReservationState extends State<Reservation> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  TextEditingController searchController = TextEditingController();
  TextEditingController dateFromController = TextEditingController();
  TextEditingController dateToController = TextEditingController();
  bool isLoading = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

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

  Future<String> _getUserUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userUID') ?? '';
  }

  Future<void> fetchItems() async {
    setState(() => isLoading = true);

    try {
      String userUID = await _getUserUID();
      final response = await http.post(
        Uri.parse(AppConfig.endpointDatabase),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_uid': userUID, 'query': 'reservation'}),
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
        throw Exception(response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: $e'),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterItems() {
    String query = searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
        int statusId = int.tryParse(item['status_id'].toString()) ?? 0;
        return (statusId == 1 || statusId == 2 || statusId == 5) &&
            (item['code']?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  String getStatusName(int statusId) {
    switch (statusId) {
      case 1:
        return 'Noliktavā';
      case 2:
        return 'Rezervēts';
      default:
        return 'Nezināms';
    }
  }

  Future<void> reserveItem(
      String itemUID, String dateFrom, String dateTo) async {
    String userUID = await _getUserUID();
    try {
      final response = await http.post(
        Uri.parse(AppConfig.endpointRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_uid': userUID,
          'event': Events.reserveItem.name,
          'item_uid': itemUID,
          'date_from': dateFrom,
          'date_to': dateTo
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = _items.indexWhere((item) => item['uid'] == itemUID);
          if (index != -1) {
            _items[index]['status_id'] = 2;
            _items[index]['user_uid'] = userUID;
          }
          _filterItems();
        });
      } else {
        throw Exception('Neizdevās rezervēt priekšmetu');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: $e'),
        ),
      );
    }
  }

  // Funkcija, kas atver datumu izvēlni
  Future<void> selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(1900);
    DateTime lastDate = DateTime(2101);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && picked != initialDate) {
      controller.text = _dateFormat.format(picked); // Formatē datumu
    }
  }

  void _showReservationDialog(String itemUID, int statusId) {
    String message;
    if (statusId == 5) {
      message =
          'Šis priekšmets varētu būt daļēji bojāts vai pilnvērtīgi nedarboties, vai tiešām vēlaties rezervēt?';
    } else {
      message = 'Vai tiešām vēlaties rezervēt šo priekšmetu?';
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apstiprinājums'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              SizedBox(height: 0), //20
              // TextField(
              //   controller: dateFromController,
              //   readOnly: true,
              //   decoration: InputDecoration(
              //     labelText: 'Datums no',
              //     suffixIcon: Icon(Icons.calendar_today),
              //   ),
              //   onTap: () => selectDate(context, dateFromController),
              // ),
              // TextField(
              //   controller: dateToController,
              //   readOnly: true,
              //   decoration: InputDecoration(
              //     labelText: 'Datums līdz',
              //     suffixIcon: Icon(Icons.calendar_today),
              //   ),
              //   onTap: () => selectDate(context, dateToController),
              // ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Atcelt'),
            ),
            TextButton(
              onPressed: () {
                reserveItem(
                    itemUID, dateFromController.text, dateToController.text);
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
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 600;

                    return DataTable(
                      columns: [
                        DataColumn(label: Text('Kods')),
                        if (!isMobile) DataColumn(label: Text('Statuss')),
                        if (!isMobile) DataColumn(label: Text('Vārds')),
                        DataColumn(label: Text('Darbības')),
                      ],
                      rows: _filteredItems.map((item) {
                        int statusId =
                            int.tryParse(item['status_id'].toString()) ?? 0;
                        return DataRow(
                          color:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                            if (statusId == 5) {
                              return Colors.red.withValues(alpha: 0.3);
                            }
                            if (statusId == 2) {
                              return Colors.yellow.withValues(alpha: 0.3);
                            }
                            return null;
                          }),
                          cells: [
                            DataCell(Text(item['code'] ?? '')),
                            if (!isMobile)
                              DataCell(Text(getStatusName(statusId))),
                            if (!isMobile) DataCell(Text(item['name'] ?? '')),
                            DataCell(
                              (statusId == 1 || statusId == 5)
                                  ? ElevatedButton(
                                      onPressed: () => _showReservationDialog(
                                          item['uid']?.toString() ?? '',
                                          statusId),
                                      child: Text('Rezervēt'),
                                    )
                                  : (statusId == 2
                                      ? Text(
                                          item['user_phone'] != null
                                              ? '${item['user_phone']}'
                                              : '',
                                          style: TextStyle(fontSize: 16),
                                        )
                                      : SizedBox.shrink()),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
