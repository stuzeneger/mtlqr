import 'package:flutter/material.dart';
import 'user_form_dialog.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Users extends StatefulWidget {
  const Users({Key? key}) : super(key: key);

  @override
  State<Users> createState() => _UsersState();
}

class _UsersState extends State<Users> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool showBlockedUsers = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/get_users.php'));
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(responseData);
          _filterUsers();
        });
      } else {
        throw Exception('Neizdevās iegūt lietotāju sarakstu');
      }
    } catch (e) {
      print('Kļūda: $e');
    }
  }

  void _filterUsers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        bool matchesSearch = user['name']?.toLowerCase().contains(query) ?? false ||
                             user['phone']?.toLowerCase().contains(query) ?? false;
        bool matchesFilter = showBlockedUsers || user['status_id'] != '3';
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _toggleShowBlockedUsers(bool value) {
    setState(() {
      showBlockedUsers = value;
      _filterUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            Switch(
              value: showBlockedUsers,
              onChanged: _toggleShowBlockedUsers,
              activeColor: Colors.red,
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
                      _filterUsers();
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
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Lietotājs')),
              if (isLargeScreen) const DataColumn(label: Text('Statuss')),
              if (isLargeScreen) const DataColumn(label: Text('Tālrunis')),
              const DataColumn(label: Text('Darbības')),
            ],
            rows: _filteredUsers.map((user) {
              return DataRow(
                cells: [
                  DataCell(Text(user['name'] ?? 'Nav')),
                  if (isLargeScreen) DataCell(Text(user['status'] ?? 'Nav')),
                  if (isLargeScreen)
                    DataCell(Text('+${user['phone_country_code'] ?? ''}${user['phone'] ?? 'Nav'}')),
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
                                    int index = _users.indexWhere((u) => u['id'] == updatedUser['id']);
                                    if (index != -1) {
                                      _users[index] = updatedUser;
                                      _filterUsers();
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                      if (user['status_id'] != '3')
                        IconButton(
                          icon: const Icon(Icons.lock),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Bloķēt lietotāju'),
                                  content: const Text('Vai tiešām vēlaties šo lietotāju bloķēt?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Atcelt'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          user['status_id'] = '3';
                                        });
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Bloķēt'),
                                    ),
                                  ],
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
