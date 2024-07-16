import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
  const MyApp({super.key});
}

class MyAppState extends State<MyApp> {
  String scanResult = "";

  @override
  void initState() {
    super.initState();
  }

  //create scan function
  Future<void> scanCode() async {
    String barcodeScanRes;

    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.BARCODE);
    } on PlatformException {
      barcodeScanRes = "Failed to scan";
    }

    setState(() {
      scanResult = barcodeScanRes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FoodInfo Finder'),
        ),
        body: Builder(builder: (BuildContext context) {
          return Container(
              alignment: Alignment.center,
              child: Flex(
                  direction: Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(onPressed: () {
                      scanCode();
                    },
                    child: const Text('Start barcode scan!')),
                  ]));
        }),
      ),
    );
  }
}
