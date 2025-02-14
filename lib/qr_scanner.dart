import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // Importē geolocator GPS iegūšanai

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String qrText = "Nav skenēts QR kods";
  bool isCameraAllowed = false;
  String userUID = ''; // Inicializējam kā tukšu stringu

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _loadUserUID(); // Iegūstam userUID no SharedPreferences
  }

  // Iegūst userUID no SharedPreferences
  Future<void> _loadUserUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userUID = prefs.getString('userUID') ?? ''; // Ja nav UID, izmanto tukšu vērtību
    });
  }

  // Pārbauda un pieprasa kameras atļauju
  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    setState(() {
      isCameraAllowed = status.isGranted;
    });
  }

  // Iegūst pašreizējo GPS atrašanās vietu
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("GPS nav ieslēgts");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("GPS atļauja liegta");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("GPS atļauja liegta uz visiem laikiem");
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // Nosūta QR kodu, userUID un GPS koordinātes uz serveri
  Future<void> _sendDataToServer(String qrCode) async {
    Position? position = await _getCurrentLocation();
    if (position == null) {
      print("Neizdevās iegūt GPS koordinātes");
      return;
    }

    final url = Uri.parse('https://droniem.lv/mtlqr/take.php'); // Tavs PHP serveris
    try {
print(position.latitude.toString());
print(position.longitude.toString());

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'qrCode': qrCode,
          'userUID': userUID,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        }),
      );

      if (response.statusCode == 200) {
        print("Dati nosūtīti veiksmīgi");

        if (mounted) {
          // Aizver skenēšanas ekrānu un atgriežas galvenajā skatā
          Future.delayed(Duration(milliseconds: 500), () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }
      } else {
        print("Kļūda pieprasījumā: ${response.statusCode}");
      }
    } catch (e) {
      print("Kļūda: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skenē QR kodu")),
      body: isCameraAllowed
          ? Column(
              children: [
                Expanded(
                  flex: 4,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        setState(() {
                          qrText = barcodes.first.rawValue ?? "Nevar nolasīt QR kodu";
                        });

                        // Pārbaudām, vai QR kods ir 6 cipari
                        if (qrText.length == 6 && int.tryParse(qrText) != null) {
                          // Kad QR kods ir 6 cipari, nosūtam datus uz serveri
                          _sendDataToServer(qrText);
                        } else {
                          print("QR kods nav 6 cipari");
                        }
                      }
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      qrText,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Nav pieejama piekļuve kamerai", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _checkCameraPermission,
                    child: const Text("Pieprasīt atļauju vēlreiz"),
                  ),
                ],
              ),
            ),
    );
  }
}
