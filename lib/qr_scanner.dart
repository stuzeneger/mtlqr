import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String qrText = "Nav skenēts QR kods";
  bool isCameraAllowed = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
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
