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
  bool isLargeScreen = false;
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
          _filteredUsers = List<Map<String, dynamic>>.from(responseData); // Inicializējam filtrētos datus
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
        return user['name']?.toLowerCase().contains(query) ?? false || 
               user['phone']?.toLowerCase().contains(query) ?? false;
      }).toList();
    });
  }

  void _addUser(Map<String, dynamic> newUser) {
    setState(() {
      _users.add(newUser);
      _filteredUsers.add(newUser);
    });
  }

  void _editUser(Map<String, dynamic> updatedUser, int index) {
    setState(() {
      _users[index] = updatedUser;
      _filteredUsers[index] = updatedUser;
    });
  }

  Color _getRowColor(String? statusId) {
    switch (statusId) {
      case '0':
        return Colors.yellow.withOpacity(0.3);
      case '2':
        return Colors.green.withOpacity(0.3);
      case '3':
        return Colors.red.withOpacity(0.3);
      default:
        return Colors.transparent;
    }
  }

  void _showBlockUserDialog(Map<String, dynamic> user, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bloķēt lietotāju'),
          content: const Text('Vai tiešām vēlaties šo lietotāju bloķēt?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Atcelt'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  user['status_id'] = '3'; // Iestata statusu uz "Bloķēts"
                });
                Navigator.of(context).pop();
              },
              child: const Text('Bloķēt'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lietotāji'),
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
                  return UserFormDialog(
                    onSubmit: _addUser,
                  );
                },
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Atjaunojam ekrāna izmēra pārbaudi, lai pareizi noteiktu lielo ekrānu
          isLargeScreen = constraints.maxWidth > 600;

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: double.infinity), // Tabula aizņem visu platumu
              child: Column(
                children: [
                  // Meklēšanas lauks
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Meklēt pēc vārda vai telefona',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  // Lietotāju tabula
                  DataTable(
                    columns: [
                      const DataColumn(label: Text('Lietotājs')),
                      if (isLargeScreen) const DataColumn(label: Text('Statuss')), // Paslēpj "Statuss" šaurākos ekrānos
                      if (isLargeScreen) const DataColumn(label: Text('Tālrunis')), // Paslēpj "Tālrunis" šaurākos ekrānos
                      const DataColumn(label: Text('Darbības')), // "Darbības" vienmēr būs redzama
                    ],
                    rows: _filteredUsers.map((user) {
                      int index = _filteredUsers.indexOf(user);
                      bool isBlocked = user['status_id'] == '3'; // Pārbaude, vai lietotājs ir bloķēts

                      return DataRow(
                        color: MaterialStateProperty.all(_getRowColor(user['status_id']?.toString())),
                        cells: [
                          DataCell(Text(user['name'] ?? 'Nav')),
                          if (isLargeScreen) DataCell(Text(user['status'] ?? 'Nav')), // Paslēpj "Statuss" šaurākos ekrānos
                          if (isLargeScreen) DataCell(Text('+${user['county_code'] ?? ''}${user['phone'] ?? 'Nav'}')), // Paslēpj "Tālrunis" šaurākos ekrānos
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return EditUserDialog(
                                          user: user,
                                          onSubmit: (updatedUser) {
                                            _editUser(updatedUser, index);
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                if (!isBlocked)
                                  IconButton(
                                    icon: const Icon(Icons.lock),
                                    onPressed: () {
                                      _showBlockUserDialog(user, index);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onSubmit;

  const EditUserDialog({Key? key, required this.user, required this.onSubmit}) : super(key: key);

  @override
  _EditUserDialogState createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedStatus;

  final Map<String, String> statusOptions = {
    '1': 'Lietotājs',
    '2': 'Administrātors',
    '3': 'Bloķēts',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _phoneController = TextEditingController(text: widget.user['phone']);
    _selectedStatus = widget.user['status_id']?.toString() ?? '1';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rediģēt lietotāju'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Vārds'),
          ),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Telefons'),
            keyboardType: TextInputType.phone,
          ),
          DropdownButtonFormField<String>( 
            value: _selectedStatus,
            decoration: const InputDecoration(labelText: 'Statuss'),
            items: statusOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedStatus = newValue;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Atcelt'),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedUser = {
              'name': _nameController.text,
              'phone': _phoneController.text,
              'status_id': _selectedStatus,
            };
            widget.onSubmit(updatedUser);
            Navigator.of(context).pop();
          },
          child: const Text('Saglabāt'),
        ),
      ],
    );
  }
}
