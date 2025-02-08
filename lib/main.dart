import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account.dart';
import 'qr_scanner.dart';
import 'login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTLQR menedžeris',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const MyHomePage(title: 'MTL') : LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _users = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    fetchData();
    fetchUsers();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      setState(() {});
    });
  }

  Future<void> fetchData() async {
    final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/get_items.php'));
    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      setState(() {
        _data = List<Map<String, dynamic>>.from(responseData);
      });
    } else {
      throw Exception('Neizdevās iegūt datus');
    }
  }

  Future<void> fetchUsers() async {
    final response = await http.get(Uri.parse('https://droniem.lv/mtlqr/get_users.php'));
    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      setState(() {
        _users = List<Map<String, dynamic>>.from(responseData);
      });
    } else {
      throw Exception('Neizdevās iegūt lietotāju sarakstu');
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyAccountScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Lietošanā'),
                Tab(text: 'Noliktava'),
                Tab(text: 'Lietotāji'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTable(includeDate: false),
                  _buildTable(includeDate: true),
                  _buildUserTable(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QRScannerScreen()),
                );
              },
              tooltip: 'Scan QR Code',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  Widget _buildTable({required bool includeDate}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Kods')),
          const DataColumn(label: Text('Veids')),
          const DataColumn(label: Text('Statuss')),
          if (includeDate) const DataColumn(label: Text('Datums')),
        ],
        rows: _data.map((item) {
          return DataRow(cells: [
            DataCell(Text(item['code'] ?? 'Nav')),
            DataCell(Text(item['type'] ?? 'Nav')),
            DataCell(Text(item['status_id'] ?? 'Nav')),
            if (includeDate) DataCell(Text(item['date'] ?? 'Nav')),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildUserTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('Vārds')),
          const DataColumn(label: Text('Telefons')),
        ],
        rows: _users.map((user) {
          return DataRow(cells: [
            DataCell(Text(user['id'].toString() ?? 'Nav')),
            DataCell(Text(user['name'] ?? 'Nav')),
            DataCell(Text(user['phone'] ?? 'Nav')),
          ]);
        }).toList(),
      ),
    );
  }
}
