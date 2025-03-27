import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeService {
  Future<String?> scanBarcode() async {
    final completer = Completer<String?>();
    final controller = MobileScannerController();

    controller.barcodes.listen((barcode) {
      if (barcode.barcodes.isNotEmpty) {
        completer.complete(barcode.barcodes.first.rawValue);
        controller.stop();
      }
    });

    await controller.start();
    final result = await completer.future;
    controller.dispose();
    return result;
  }
}