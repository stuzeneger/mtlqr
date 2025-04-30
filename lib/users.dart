import 'services/config.dart';
import 'package:flutter/material.dart';
import 'user_form_dialog.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';

class Users extends StatefulWidget {
  const Users({super.key});

  @override
  State<Users> createState() => _UsersState();
}

class _UsersState extends State<Users> {
  List<Map<String, dynamic>> _users = [];
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
    searchController.addListener(_filterUsers);
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String userUID = prefs.getString('userUID') ?? '';
      final response = await http.post(
        Uri.parse(AppConfig.endpointDatabase),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_uid': userUID, 'query': 'users'}),
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
          var items = responseData['items'];
          if (items is String) {
            items = json.decode(items);
          }
          if (items is List) {
            setState(() {
              _users = List<Map<String, dynamic>>.from(items);
              isLoading = false;
            });
          } else {
            throw Exception('Datu struktūra nav derīga');
          }
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
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterUsers() {
    String query = searchController.text.toLowerCase();
    setState(() {
      _users = _users.where((user) {
        return (user['name']?.toLowerCase().contains(query) ?? false) ||
            formatPhoneNumber(user['country_code'], user['phone'])
                .toLowerCase()
                .contains(query);
      }).toList();
    });
  }

  String formatPhoneNumber(String? countryCode, String? phoneNumber) {
    if (countryCode == null ||
        countryCode.isEmpty ||
        phoneNumber == null ||
        phoneNumber.isEmpty) {
      return 'Nav';
    }
    return '+$countryCode$phoneNumber';
  }

  String getStatusLabel(String statusId) {
    switch (statusId) {
      case '1':
        return 'Lietotājs';
      case '2':
        return 'Pārzinis';
      case '3':
        return 'Bloķēts';
      case '0':
        return 'Ielūgts';
      default:
        return 'Nezināms';
    }
  }

  Color getStatusColor(String statusId) {
    switch (statusId) {
      case '1':
        return Colors.green;
      case '2':
        return Colors.blue;
      case '3':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUsers,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return UserFormDialog(onSubmit: (newUser) {
                    setState(() {
                      _users.add(newUser);
                    });
                  });
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Lietotājs')),
                    if (isLargeScreen) const DataColumn(label: Text('Statuss')),
                    if (isLargeScreen)
                      const DataColumn(label: Text('Tālrunis')),
                    const DataColumn(label: Text('Darbības')),
                  ],
                  rows: _users.map((user) {
                    Color rowColor =
                        getStatusColor(user['status_id'].toString());
                    return DataRow(
                      color: WidgetStateProperty.all(
                          rowColor.withValues(alpha: 0.3)),
                      cells: [
                        DataCell(Text(user['name'] ?? '')),
                        if (isLargeScreen)
                          DataCell(Text(
                              getStatusLabel(user['status_id'].toString()))),
                        if (isLargeScreen)
                          DataCell(Text(formatPhoneNumber(
                              user['country_code'], user['phone']))),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return UserFormDialog(
                                      user: user,
                                      onSubmit: (updatedUser) {
                                        setState(() {
                                          int index = _users.indexWhere((u) =>
                                              u['uid'] == updatedUser['uid']);
                                          if (index != -1) {
                                            _users[index] = updatedUser;
                                          }
                                        });
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
