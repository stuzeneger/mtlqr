import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account.dart';
import 'qr_scanner.dart';
import 'login.dart';
import 'taken.dart';
import 'reservation.dart';
import 'users.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  bool isAdmin = prefs.getBool('isAdmin') ?? false;

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
    // Ja lietotājs nav administrators, izņemam 3. tab (Lietotāji)
    _tabController = TabController(length: widget.isAdmin ? 3 : 2, vsync: this);
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
        length: widget.isAdmin ? 3 : 2, // Ja nav admins, tab garums ir 2
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                const Tab(text: 'Lietošanā'),
                const Tab(text: 'Noliktava'),
                if (widget.isAdmin) const Tab(text: 'Lietotāji'), // "Lietotāji" tikai adminiem
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Taken(),
                  Reservation(),
                  if (widget.isAdmin) Users(), // "Lietotāji" tikai adminiem
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
}
