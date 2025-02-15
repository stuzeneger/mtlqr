import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; 

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String qrText = "Nav skenēts QR kods";
  bool isCameraAllowed = false;
  String userUID = '';
  bool isScanning = true;
  TextEditingController _manualInputController = TextEditingController();

  // Jauns mainīgais GPS koordinātu saglabāšanai
  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _loadUserUID();
    _getLocation(); // Iegūstam GPS koordinātes
  }

  Future<void> _loadUserUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userUID = prefs.getString('userUID') ?? '';
    });
  }

  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    setState(() {
      isCameraAllowed = status.isGranted;
    });
  }

  // Jauns funkcijas iestatījums GPS koordinātu iegūšanai
  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Pārbaudām, vai GPS serviss ir ieslēgts
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS serviss nav iespējots');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      print('Piekļuve atrašanās vietai ir pastāvīgi noraidīta');
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print('Piekļuve atrašanās vietai nav piešķirta');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }

  Future<void> _sendDataToServer(String qrCode) async {

    final url = Uri.parse('https://droniem.lv/mtlqr/take.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'qr_code': qrCode,
          'user_uid': userUID,
          'latitude': latitude,
          'longitude': longitude
        }),
      );




      if (response.statusCode == 200) {
        print("Dati nosūtīti veiksmīgi");
        setState(() {
          isScanning = false;
        });
        Navigator.pop(context);
      } else {
        print("Kļūda pieprasījumā: \${response.statusCode}");
      }
    } catch (e) {
      print("Kļūda: \$e");
    }
  }

  void _onManualInputChanged(String value) {
    if (value.length == 6 && int.tryParse(value) != null) {
      _sendDataToServer(value);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && qrText != barcodes.first.rawValue) {
      setState(() {
        qrText = barcodes.first.rawValue ?? "Nevar nolasīt QR kodu";
      });
      if (qrText.length == 6 && int.tryParse(qrText) != null) {
        _sendDataToServer(qrText);
      }
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
                  child: isScanning
                      ? MobileScanner(
                          onDetect: _onDetect,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("QR kods nolasīts un dati nosūtīti.", style: TextStyle(fontSize: 18)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isScanning = true;
                                  });
                                },
                                child: const Text("Skenēt atkal"),
                              ),
                            ],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _manualInputController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: "Ievadi 6 ciparu kodu",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onManualInputChanged,
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
