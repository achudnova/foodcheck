import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _favorites = [];
  String scanResult = "";
  String productInfo = "";
  String productImage = "";
  Map<String, dynamic>? currentProduct;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        currentProduct = product['product'];
      });
    } else {
      setState(() {
        productInfo = 'Product not found or unable to fetch the product information.';
        productImage = '';
        currentProduct = null;
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

  Future<void> _addToFavorites() async {
    if (currentProduct != null) {
      setState(() {
        _favorites.add(currentProduct!);
      });
      await _saveFavorites();
    }
  }

  Future<void> _deleteFromFavorites(int index) async {
    setState(() {
      _favorites.removeAt(index);
    });
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favoriteStrings = _favorites.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('favorites', favoriteStrings);
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? favoriteStrings = prefs.getStringList('favorites');
    if (favoriteStrings != null) {
      setState(() {
        _favorites = favoriteStrings.map((item) => jsonDecode(item)).toList().cast<Map<String, dynamic>>();
      });
    }
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            onPressed: scanCode,
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
          if (currentProduct != null)
            IconButton(
              icon: const Icon(Icons.favorite),
              color: Colors.red,
              onPressed: _addToFavorites,
            ),
        ],
      ),
    );
  }

  Widget _buildFavorites() {
    return ListView.builder(
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final product = _favorites[index];
        return ListTile(
          title: Text(product['product_name'] ?? 'N/A'),
          subtitle: Text(product['brands'] ?? 'N/A'),
          leading: product['image_url'] != null
              ? Image.network(product['image_url'], width: 50, height: 50)
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () => _deleteFromFavorites(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FoodInfo Finder'),
        ),
        body: _selectedIndex == 0 ? _buildHome() : _buildFavorites(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.amber[800],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
