import 'services/config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'qr_scanner.dart';
import 'models/scan.dart';
import 'models/event.dart';

class Takens extends StatefulWidget {
  final VoidCallback onScanPressed;

  const Takens({super.key, required this.onScanPressed});

  @override
  TakenState createState() => TakenState();
}

class TakenState extends State<Takens> {
  List<Map<String, dynamic>> _data = [];
  bool isLoading = false;

  static const Map<int, String> statusMap = {
    2: 'Rezervēts',
    3: 'Izsniegts',
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
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';
    final response = await http.post(
      Uri.parse(AppConfig.endpointDatabase),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_uid': userUID, 'query': 'takens'}),
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
        final List<dynamic> items = responseData['items'] != null
            ? json.decode(responseData['items'])
            : [];
        setState(() => _data = List<Map<String, dynamic>>.from(items));
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> cancelReservation(String itemUID) async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';
    final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_uid': userUID,
        'event': Events.cancelReservation.name,
        'item_uid': itemUID
      }),
    );
    String message = "Rezervācija atcelta";
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        fetchData();
      } else {
        message = 'Atcelšana neizdevās: ${responseData['message']}';
      }
    }
    setState(() => isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

Future<void> returnItem(String itemUID) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QRScannerScreen(
        scanType: Scan.returning,
        itemUID: itemUID,
      ),
    ),
  );
    await fetchData();
}

  void _showCancelConfirmationDialog(String itemUID) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apstiprinājums'),
          content: Text('Vai tiešām vēlaties atcelt šo rezervāciju?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Atcelt')),
            TextButton(
              onPressed: () {
                cancelReservation(itemUID);
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
    bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData)
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: DataTable(
                columns: isSmallScreen
                    ? const [
                        DataColumn(label: Text('Kods')),
                        DataColumn(label: Text('Darbība')),
                      ]
                    : const [
                        DataColumn(label: Text('Kods')),
                        DataColumn(label: Text('Statuss')),
                        DataColumn(label: Text('Datums')),
                        DataColumn(label: Text('Darbības')),
                      ],
                rows: _data.map((item) {
                  int statusId =
                      int.tryParse(item['status_id'].toString()) ?? 0;
                  String? itemUID =
                      item.containsKey('uid') ? item['uid'] : null;

                  Color? rowColor;
                  if (statusId == 2) {
                    rowColor = Colors.yellow.shade200;
                  }

                  return DataRow(
                    color: rowColor != null
                        ? WidgetStateProperty.all(rowColor)
                        : null,
                    cells: isSmallScreen
                        ? [
                            DataCell(Text(item['code'] ?? 'Nav')),
                            DataCell(
                              Row(
                                children: [
                                  if (statusId == 2 && itemUID != null)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        _showCancelConfirmationDialog(itemUID);
                                      },
                                      child: Text('Atcelt rezervāciju'),
                                    ),
                                  if (statusId == 3 && itemUID != null)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        returnItem(itemUID);
                                      },
                                      child: Text('Atgriezt'),
                                    ),
                                ],
                              ),
                            ),
                          ]
                        : [
                            DataCell(Text(item['code'] ?? 'Nav')),
                            DataCell(Text(getStatusName(statusId))),
                            DataCell(Text(item['date'] ?? '')),
                            DataCell(
                              Row(
                                children: [
                                  if (statusId == 2 && itemUID != null)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        _showCancelConfirmationDialog(itemUID);
                                      },
                                      child: Text('Atcelt rezervāciju'),
                                    ),
                                  if (statusId == 3 && itemUID != null)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        returnItem(itemUID);
                                      },
                                      child: Text('Atgriezt'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
