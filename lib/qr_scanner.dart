import 'services/config.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'models/scan.dart';
import 'models/event.dart';

class QRScannerScreen extends StatefulWidget {
  final Scan scanType;
  final String? itemUID;

  const QRScannerScreen({super.key, required this.scanType, this.itemUID});

  @override
  QRScannerScreenState createState() => QRScannerScreenState();
}

class QRScannerScreenState extends State<QRScannerScreen> {
  Map<String, dynamic>? itemData;
  String qrText = "Nav skenēts QR kods";
  bool isCameraAllowed = false;
  String userUID = '';
  bool isScanning = true;
  TextEditingController manualInputController = TextEditingController();
  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _loadUserUID();
    _getLocation();
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

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }

  Future<void> takeItem(String itemUID, String userUID) async {
    final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'event': Events.takeItem.name,
        'user_uid': userUID,
        'item_uid': itemUID,
      }),
    );
    String message = 'Priekšmets paņemts';
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['result'] != true) {
        message = 'Priekšmets nav pieejams';
      }
    } else {
      message = 'Kļūda priekšmeta pārņemšanā';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.pop(context);
  }

  Future<void> returnItem(String itemUID, String userUID) async {
    final response = await http.post(
      Uri.parse(AppConfig.endpointRequest),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'event': Events.returnItem.name,
        'user_uid': userUID,
        'item_uid': itemUID,
      }),
    );
    String message = 'Priekšmets atgriezts noliktavā';
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['result'] != true) {
        message = 'Priekšmets nav pieejams';
      }
    } else {
      message = 'Kļūda priekšmeta atgriešanā';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.pop(context);
  }

  Future<void> _sendDataToServer(String qrCode) async {
    switch (widget.scanType) {
      case Scan.returning:
        if (qrCode == AppConfig.baseRTHCode) {
          returnItem(widget.itemUID ?? '', userUID);
        }
      default:
        try {
          final response = await http.post(
            Uri.parse(AppConfig.endpointRequest),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'event': Events.checkItem.name,
              'user_uid': userUID,
              'qr_code': qrCode,
              'latitude': latitude,
              'longitude': longitude,
            }),
          );
          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            if (responseData['result'] != null &&
                responseData['result'] != false) {
              itemData = responseData['result'];
              String itemUID = itemData?['uid']?.toString() ?? '';
              String itemUserUID = itemData?['user_uid']?.toString() ?? '';
              int statusId =
                  int.tryParse(itemData?['status_id']?.toString() ?? '') ?? 0;
              bool isDamaged =
                  int.tryParse(itemData?['damaged']?.toString() ?? '') == 1;
              if (isDamaged && statusId != 3) {
                if (!mounted) return;
                bool isConfirmed =
                    await showTakingDamagedItemDialog(context, itemUID);
                if (!isConfirmed && mounted) {
                  Navigator.pop(context);
                  return;
                }
              }
              switch (statusId) {
                case 1:
                  //noliktavā un pieejams ņemšanai lietošanā
                  takeItem(itemUID, userUID);
                  break;
                case 2:
                  if (userUID == itemUserUID) {
                    //rezervējis lietotājs
                    takeItem(itemUID, userUID);
                  } else {
                    //item rezervējis cits lietotājs, lūdz sazināties
                    showReservedByOtherDialog();
                  }
                  break;
                case 3:
                  if (userUID != itemUserUID) {
                    //pārņemam cita lietotāja priekšmetu
                    showTakeOverItemDialog(itemUID, itemUserUID);
                  } else {
                    showAlreadyTakedDialog();
                  }
                  break;
                default:
              }
            }
          } else {
            throw Exception(response.statusCode);
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kļūda: $e'),
            ),
          );
        }
    }
  }

  void showReservedByOtherDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Paziņojums"),
          content: Text(
              "Šo priekšmetu ir rezervējis cits lietotājs! Lūdzu sazinieties ar viņu, lai atceltu rezervāciju!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void showAlreadyTakedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Paziņojums"),
          content: Text("Šis priekšmets jau atraodas jūsu lietošanā!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> showTakingDamagedItemDialog(
      BuildContext context, String itemUid) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Brīdinājums"),
          content: Text("Šis priekšmets ir bojāts. Jūs vienalga viņu ņemsiet?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false); // Ja atceļ
              },
              child: Text("Atcelt"),
            ),
            TextButton(
              onPressed: () async {
                await submitDamageItem(itemUid);
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(dialogContext, true); // Ja apstiprina
              },
              child: Text("Apstiprināt"),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Future<void> submitDamageItem(String itemUid) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.endpointRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'event': Events.submitDamageItem.name,
          'user_uid': userUID,
          'item_uid': itemUid,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: $e'),
        ),
      );
    }
  }

  void showTakeOverItemDialog(String itemUid, String itemUserUID) {
    TextEditingController noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text("Brīdinājums"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "Šis priekšmets atrodas lietošanā. Vai jūs apstiprināt priekšmeta pārņemšanu? Esošajam lietotājam aplikācijā būs jāapstiprina atdošanu."),
            SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "Ievadiet piezīmes",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Aizver dialogu
            child: Text("Atcelt"),
          ),
          TextButton(
            onPressed: () async {
              String notes = noteController.text;
              await _confirmTakeOver(itemUid, itemUserUID, notes);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text("Apstiprināt"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTakeOver(
      String itemUID, String itemUserUID, String notes) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.endpointRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'event': Events.confirmTakeover.name,
          'user_uid': userUID,
          'current_user_uid': itemUserUID,
          'item_uid': itemUID,
          'notes': notes,
        }),
      );
      String message = "Nosūtīts pieprasījums priekšmeta pārņemšanai";
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['result'] != true) {
          message = 'Kļūda priekšmeta pārņemšanā';
        }
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else {
        throw Exception(response.statusCode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kļūda: $e'),
        ),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && qrText != barcodes.first.rawValue) {
      setState(() {
        qrText = barcodes.first.rawValue ?? "Nevar nolasīt QR kodu";
              if ((qrText.length == 6 && int.tryParse(qrText) != null) ||
          (qrText == AppConfig.baseRTHCode)) {
        _sendDataToServer(qrText);
      }
      });       
    }
  }

  void _onManualInputChanged(String value) {
    if ((value.length == 6 && int.tryParse(value) != null) ||
        (value == AppConfig.baseRTHCode)) {
      _sendDataToServer(value);
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
                              const Text("QR kods nolasīts un dati nosūtīti.",
                                  style: TextStyle(fontSize: 18)),
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
                    controller: manualInputController,
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
                  const Text("Nav pieejama piekļuve kamerai",
                      style: TextStyle(fontSize: 18)),
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
