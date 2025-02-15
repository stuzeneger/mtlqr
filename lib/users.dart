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
  bool isLoading = false;  // Jauns mainīgais, lai uzglabātu ielādes statusu

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;  // Uzstādam ielādes statusu uz true
    });
    try {
      final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/users.php'));
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
    } finally {
      setState(() {
        isLoading = false;  // Kad dati ir iegūti vai gadījumā notikusi kļūda, ielāde ir pabeigta
      });
    }
  }

  void _filterUsers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        bool matchesSearch = (user['name']?.toLowerCase().contains(query) ?? false) ||
                             (formatPhoneNumber(user['country_code'], user['phone'])?.toLowerCase().contains(query) ?? false);
        bool matchesFilter = showBlockedUsers || user['status_id'] != '3';
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  String formatPhoneNumber(String? countryCode, String? phoneNumber) {
    if (countryCode == null || countryCode.isEmpty || phoneNumber == null || phoneNumber.isEmpty) {
      return 'Nav';
    }
    return '+$countryCode$phoneNumber';
  }

  void _toggleShowBlockedUsers(bool value) {
    setState(() {
      showBlockedUsers = value;
      _filterUsers();
    });
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
        child: isLoading
            ? Center(child: CircularProgressIndicator()) // Parādām rimbulīti, kamēr dati tiek ielādēti
            : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Lietotājs')),
                    if (isLargeScreen) const DataColumn(label: Text('Statuss')),
                    if (isLargeScreen) const DataColumn(label: Text('Tālrunis')),
                    const DataColumn(label: Text('Darbības')),
                  ],
                  rows: _filteredUsers.map((user) {
                    Color rowColor = getStatusColor(user['status_id'].toString());

                    return DataRow(
                      color: MaterialStateProperty.all(rowColor.withOpacity(0.1)),  // Iekrāsojam rindu
                      cells: [
                        DataCell(Text(user['name'] ?? 'Nav')),
                        if (isLargeScreen)
                          DataCell(
                            Text(user['status'] ?? 'Nav'),  // Noņemta krāsa no statusa
                          ),
                        if (isLargeScreen)
                          DataCell(Text(formatPhoneNumber(user['country_code'], user['phone']))),
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
                                  setState(() {
                                    user['status_id'] = '3';
                                  });
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
