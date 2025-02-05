import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_account.dart';
import 'qr_scanner.dart';
import 'login_screen.dart';
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
      home: isLoggedIn ? const MyHomePage(title: 'Tehnisko līdzekļu uzkaites rīks') : LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    fetchData();
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
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Lietošanā'),
                Tab(text: 'Noliktava'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTable(includeDate: false),
                  _buildTable(includeDate: true),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QRScannerScreen()),
          );
        },
        tooltip: 'Scan QR Code',
        child: const Icon(Icons.qr_code_scanner),
      ),
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
}
