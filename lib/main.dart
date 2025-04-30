import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'account.dart';
import 'qr_scanner.dart';
import 'login.dart';
import 'takens.dart';
import 'reservation.dart';
import 'users.dart';
import 'warehouse.dart';
import 'services/auth_service.dart';
import 'models/scan.dart';
import 'models/event.dart';

ValueNotifier<bool> isAdminNotifier = ValueNotifier<bool>(false);
Key _tabKey = UniqueKey(); 

void main() async {
  await dotenv.load(); 
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: isLoggedIn
          ? MyHomePage(title: 'MTL', isAdmin: isAdmin)
          : LoginScreen(),
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
        late TabController _tabController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: widget.isAdmin ? 2 : 2, // Ja būs vairāk sadaļu, jāpielāgo
      vsync: this,
    );

    _tabController.addListener(() {
      setState(() {}); // Lai FloatingActionButton pareizi atjaunotos
    });

    _startRequestChecking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

//Lai nestrādā taimeris, kad aplikācija nav aktīva
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopRequestChecking(); // Stop when app is not in foreground
    } else if (state == AppLifecycleState.resumed) {
      _startRequestChecking(); // Resume when app returns to foreground
    }
  }

  void _startRequestChecking() {
    _timer = Timer.periodic(Duration(seconds: 10), (_) async {
      await _checkForRequests();
    });
  }

  void _stopRequestChecking() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  Future<String> _getUserUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userUID') ?? '';
  }

  // Priekšmetu pieprasījumu pārņemšanas pārbaude
  Future<void> _checkForRequests() async {
    String userUID = await _getUserUID();
    final response = await http.post(
      Uri.parse(AppConfig.endpointDatabase),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_uid': userUID, 'query': 'requests'}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final records = json.decode(responseData['items']);
      if (records.isNotEmpty) {
        final Map<String, dynamic> record = records.first;
        if (record['current_user_uid'] == userUID &&
            int.tryParse(record['status_id'].toString()) == 1) {
          _showRequestDialog(record);
        } else {
          if (int.tryParse(record['status_id'].toString()) == 2 &&
              int.tryParse(record['active'].toString()) == 1) {
            _deactivateRequest(record);
            reloadTabs();
          }
        }
      }
    }
  }

  void _showRequestDialog(Map<String, dynamic> request) {
    _stopRequestChecking();
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController notesController = TextEditingController();
        bool isDamaged = false; // Noklusējuma vērtība checkbox
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Pieprasījums MTL pārņemšanai"),
              content: SingleChildScrollView(
                // Piešķiram scroll, ja ir daudz satura
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        "No ${request['name']} pieprasījums ${request['code']} pārņemšanai"),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: isDamaged,
                          onChanged: (bool? value) {
                            setState(() {
                              isDamaged = value ?? false;
                            });
                          },
                        ),
                        Text("Priekšmets bojāts"),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(labelText: 'Piezīmes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _declineRequest(request);
                    _startRequestChecking();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Atteikt"),
                ),
                TextButton(
                  onPressed: () async {
                    await _approveRequest(
                        request, notesController.text, isDamaged);
                    _startRequestChecking();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Apstiprināt"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Pieprasījumu pārņemšanas deaktivizācija
  Future<void> _deactivateRequest(Map<String, dynamic> request) async {
    String userUID = await _getUserUID();
   await http.post(
      Uri.parse(AppConfig.endpointRequest),
      body: json.encode({
        'event': Events.deactivateRequest.name,
        'item_uid': request['item_uid'],
        'user_uid': userUID,
      }),
    );
  }

  // Pieprasījumu apstiprināšana no tekošā priekšmeta lietotāja
  Future<void> _approveRequest(
      Map<String, dynamic> request, String notes, bool isDamaged) async {
    String userUID = await _getUserUID();
     final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      body: json.encode({
        'event': Events.acceptRequest.name,
        'item_uid': request['item_uid'],
        'user_uid': userUID,
        'request_user_uid': request['user_uid'],
        'is_damaged': isDamaged,
        'notes': notes,
      }),
    );
    String message = 'Priekšmets nodots';
    if (response.statusCode != 200) {
      message = 'Kļūda priekšmeta nodošanā';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    reloadTabs();    
  }

  Future<void> _declineRequest(Map<String, dynamic> request) async {
    String userUID = await _getUserUID();
    await http.post(
      Uri.parse(AppConfig.endpointRequest),
      body: json.encode({
        'event': Events.declineRequest,
        'user_uid': userUID,
        'item_uid': request['item_uid'],
      }),
    );
  }

  Future<void> openQrScanner(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => QRScannerScreen(scanType: Scan.take)),
  );
    reloadTabs(); 
  }

  void reloadTabs() {
    setState(() {
      _tabKey = UniqueKey(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Noņem atpakaļbultiņu
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
            onPressed: () async {
              await AuthService.logoutUser(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: isAdminNotifier,
            builder: (context, isAdmin, child) {
              return TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  if (!isAdmin) ...[
                    const Tab(text: 'Lietošanā'),
                    const Tab(text: 'Rezervēšana'),
                  ],
                  if (isAdmin) ...[
                    const Tab(text: 'Noliktava'),
                    const Tab(text: 'Lietotāji'),
                  ],
                ],
              );
            },
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: isAdminNotifier,
              builder: (context, isAdmin, child) {
                return TabBarView(
                  key: _tabKey, // Ļauj pārlādēt visu Tab skatu
                  controller: _tabController,
                  children: [
                    if (!isAdmin) ...[Takens(onScanPressed: () => openQrScanner(context)), Reservation()],
                    if (isAdmin) ...[Warehouse(), Users()],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => openQrScanner(context), // ← ŠEIT TIKA MAINĪTS
              tooltip: 'Skanēt kodu',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }
}
