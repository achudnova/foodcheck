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
  final TextEditingController _barcodeController = TextEditingController();

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
      _barcodeController.text = barcodeScanRes;
    });

    if (barcodeScanRes != '-1') {
      fetchProductDetails(barcodeScanRes);
    }
  }

  Future<void> fetchProductDetails(String barcode) async {
    final response = await http.get(Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json'));

    if (response.statusCode == 200) {
      final product = jsonDecode(response.body);
      setState(() {
        productInfo = _formatProductInfo(product);
        productImage = _getProductImage(product);
        currentProduct = product['product'];
      });
    } else {
      setState(() {
        productInfo =
            'Product not found or unable to fetch the product information.';
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
Quantity: ${productData['quantity'] ?? 'N/A'}
Nutrition Grade: ${(productData['nutrition_grades_tags'] != null ? productData['nutrition_grades_tags'][0].toUpperCase() : 'N/A')}
Ingredients: ${productData['ingredients_text'] ?? 'N/A'}
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
    if (currentProduct != null && !_isFavorite(currentProduct!)) {
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

  Future<void> _removeFromFavorites(Map<String, dynamic> product) async {
    setState(() {
      _favorites.removeWhere((item) => item['code'] == product['code']);
    });
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favoriteStrings =
        _favorites.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('favorites', favoriteStrings);
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? favoriteStrings = prefs.getStringList('favorites');
    if (favoriteStrings != null) {
      setState(() {
        _favorites = favoriteStrings
            .map((item) => jsonDecode(item))
            .toList()
            .cast<Map<String, dynamic>>();
      });
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    setState(() {
      productInfo = _formatProductInfo({'status': 1, 'product': product});
      productImage = product['image_url'] ?? '';
      currentProduct = product;
      _selectedIndex = 0;
    });
  }

  void _resetOutput() {
    setState(() {
      scanResult = "";
      productInfo = "";
      productImage = "";
      currentProduct = null;
      _barcodeController.clear();
    });
  }

  bool _isFavorite(Map<String, dynamic> product) {
    return _favorites.any((item) => item['code'] == product['code']);
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Enter barcode',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          fetchProductDetails(_barcodeController.text);
                        },
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                if (currentProduct != null)
                  IconButton(
                    icon: Icon(
                      _isFavorite(currentProduct!)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    color: _isFavorite(currentProduct!) ? Colors.red : Colors.black,
                    onPressed: () {
                      if (_isFavorite(currentProduct!)) {
                        _removeFromFavorites(currentProduct!);
                      } else {
                        _addToFavorites();
                      }
                    },
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: scanCode,
                child: const Text('Start barcode scan!'),
              ),
              ElevatedButton(
                onPressed: _resetOutput,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (productImage.isNotEmpty)
            Center(child: Image.network(productImage)),
          const SizedBox(height: 20),
          if (productInfo.isNotEmpty)
            Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 16),
                      children: _formatProductInfoSpans(),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 20),
                _buildNutritionTable(),
              ],
            ),
        ],
      ),
    );
  }

  List<TextSpan> _formatProductInfoSpans() {
    final productData = currentProduct ?? {};
    return [
      _boldSpan('Product Name: '),
      TextSpan(text: '${productData['product_name'] ?? 'N/A'}\n'),
      _boldSpan('Quantity: '),
      TextSpan(text: '${productData['quantity'] ?? 'N/A'}\n'),
      _boldSpan('Nutrition Grade: '),
      TextSpan(text: '${(productData['nutrition_grades_tags'] != null ? productData['nutrition_grades_tags'][0].toUpperCase() : 'N/A')}\n'),
      _boldSpan('Ingredients: '),
      TextSpan(text: '${productData['ingredients_text'] ?? 'N/A'}\n'),
    ];
  }

  TextSpan _boldSpan(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildNutritionTable() {
    final productData = currentProduct ?? {};
    return Table(
      border: TableBorder.all(),
      children: [
        TableRow(children: [
          _buildTableCell('Kalorien'),
          _buildTableCell('${productData['nutriments']?['energy-kcal_100g'] ?? 'N/A'}'),
        ]),
        TableRow(children: [
          _buildTableCell('Fett'),
          _buildTableCell('${productData['nutriments']?['fat_100g'] ?? 'N/A'}'),
        ]),
        TableRow(children: [
          _buildTableCell('Zucker'),
          _buildTableCell('${productData['nutriments']?['sugars_100g'] ?? 'N/A'}'),
        ]),
        TableRow(children: [
          _buildTableCell('Proteine'),
          _buildTableCell('${productData['nutriments']?['proteins_100g'] ?? 'N/A'}'),
        ]),
      ],
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildFavorites() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0), // Adjust the padding value as needed
      child: ListView.builder(
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final product = _favorites[index];
          return ListTile(
            title: Text(product['product_name'] ?? 'N/A'),
            leading: product['image_url'] != null
                ? Image.network(product['image_url'], width: 50, height: 50)
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _deleteFromFavorites(index),
            ),
            onTap: () => _showProductDetails(product),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FoodInfo Finder'),
          elevation: 20,
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
          selectedItemColor: const Color.fromARGB(255, 137, 88, 161),
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
