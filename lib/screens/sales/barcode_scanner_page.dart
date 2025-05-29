import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _isScanCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (barcodeCapture) {
          if (_isScanCompleted) return;

          final barcode = barcodeCapture.barcodes.first.rawValue;

          if (barcode != null && barcode.isNotEmpty) {
            _isScanCompleted = true;
            Navigator.pop(context, barcode);
          }
        },
      ),
    );
  }
}
