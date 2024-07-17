import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String scanResult = "";
  String productInfo = "";
  String productImage = "";

  @override
  void initState() {
    super.initState();
  }

  Future<void> scanCode() async {
    String barcodeScanRes;

    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.BARCODE);
    } on PlatformException {
      barcodeScanRes = "Failed to scan";
    }

    if (!mounted) return;

    setState(() {
      scanResult = barcodeScanRes;
    });

    if (barcodeScanRes != '-1') {
      fetchProductDetails(barcodeScanRes);
    }
  }

  Future<void> fetchProductDetails(String barcode) async {
    final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'));

    if (response.statusCode == 200) {
      final product = jsonDecode(response.body);
      setState(() {
        productInfo = _formatProductInfo(product);
        productImage = _getProductImage(product);
      });
    } else {
      setState(() {
        productInfo = 'Product not found or unable to fetch the product information.';
        productImage = '';
      });
    }
  }

  String _formatProductInfo(Map<String, dynamic> product) {
    if (product['status'] == 1) {
      final productData = product['product'];
      return '''
      Product Name: ${productData['product_name'] ?? 'N/A'}
      Brand: ${productData['brands'] ?? 'N/A'}
      Quantity: ${productData['quantity'] ?? 'N/A'}
      Ingredients: ${productData['ingredients_text'] ?? 'N/A'}
      Nutrition Grade: ${productData['nutrition_grades_tags'] != null ? productData['nutrition_grades_tags'][0] : 'N/A'}
      Categories: ${productData['categories_tags'] ?? 'N/A'}
      URL: ${productData['url'] ?? 'N/A'}
      ''';
    } else {
      return 'Product not found or unable to fetch the product information.';
    }
  }

  String _getProductImage(Map<String, dynamic> product) {
    if (product['status'] == 1) {
      final productData = product['product'];
      return productData['image_url'] ?? '';
    } else {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FoodInfo Finder'),
        ),
        body: Builder(builder: (BuildContext context) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    scanCode();
                  },
                  child: const Text('Start barcode scan!'),
                ),
                const SizedBox(height: 20),
                if (productImage.isNotEmpty)
                  Image.network(productImage),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Text(
                    productInfo,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
