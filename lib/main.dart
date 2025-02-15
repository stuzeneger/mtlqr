import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account.dart';
import 'qr_scanner.dart';
import 'login.dart';
import 'takens.dart';
import 'reservation.dart';
import 'users.dart';
import 'warehouse.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  bool isAdmin = prefs.getBool('isAdmin') ?? false;

  print('Is Admin: $isAdmin');

  runApp(MyApp(isLoggedIn: isLoggedIn, isAdmin: isAdmin));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isAdmin;
  const MyApp({super.key, required this.isLoggedIn, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTLQR menedžeris',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: isLoggedIn ? MyHomePage(title: 'MTL', isAdmin: isAdmin) : LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final bool isAdmin;
  const MyHomePage({super.key, required this.title, required this.isAdmin});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isAdmin ? 4 : 3, vsync: this); // Mainīgs garums
    _tabController.addListener(() {
      setState(() {}); // Lai FloatingActionButton pareizi atjaunotos
    });
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isAdmin', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              const Tab(text: 'Priekšmeti'),
              const Tab(text: 'Rezervēšana'),
              if (widget.isAdmin) const Tab(text: 'Noliktava'), // Jauna sadaļa
              if (widget.isAdmin) const Tab(text: 'Lietotāji'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Takens(),
                Reservation(),
                if (widget.isAdmin) Warehouse(), // Jauna sadaļa
                if (widget.isAdmin) Users(),    
              ],
            ),
          ),
        ],
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
}
