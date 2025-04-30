import 'services/config.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/event.dart';

class RequestsPage extends StatefulWidget {
  
  const RequestsPage({super.key});

  @override
  RequestsPageState createState() => RequestsPageState();
}

class RequestsPageState extends State<RequestsPage> {
  bool isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();  // Sākam taimeri
  }

  @override
  void dispose() {
    _timer?.cancel(); // Atceļam taimeri, kad lapa tiek aizvērta
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkForNewRequest();  
    });
  }

  Future<void> _checkForNewRequest() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';
    final response = await http.post(
      Uri.parse(AppConfig.endpointDatabase),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_uid': userUID, 'query': 'get_new_request'}),  // Pārbauda tikai jaunu pieprasījumu
    );
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final Map<String, dynamic> request = responseData['request'] ?? {};    
      if (request.isNotEmpty) {
        _showRequestDialog(request);
      }
    } else {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: ${response.statusCode}'),
        ),
      );
    }
    setState(() => isLoading = false);
  }

  void _showRequestDialog(Map<String, dynamic> request) {
    String? notes;    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Jauns pieprasījums'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ir jauns pieprasījums ar ID: ${request['item_uid']}'),
              TextField(
                onChanged: (value) {
                  notes = value;
                },
                decoration: InputDecoration(hintText: 'Piezīmes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  // Aizvērt dialogu
              },
              child: Text('Atcelt'),
            ),
            TextButton(
              onPressed: () {
                if (notes != null && notes!.isNotEmpty) {
                  _approveRequest(request['item_uid'], notes!);
                }
                Navigator.of(context).pop();  // Aizvērt dialogu
              },
              child: Text('Apstiprināt'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveRequest(String itemUID, String notes) async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userUID = prefs.getString('userUID') ?? '';
    final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_uid': userUID,
        'event': Events.approveRequest.name,
        'item_uid': itemUID,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      String message = "Pieprasījums apstiprināts";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kļūda: ${response.statusCode}')),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pieprasījumi')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: Text('Pārbaudiet jaunos pieprasījumus katras 10 sekundes'),
            ),
    );
  }
}
