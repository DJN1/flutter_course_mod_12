import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'product.dart';

import '../models/http_exception.dart';

class Products with ChangeNotifier {
  List<Product> _items = [];

  final String authToken;
  final String userId;

  Products(this.authToken, this.userId);

  List<Product> get favoriteItems {
    return _items.where((product) => product.isFavorite).toList();
  }

  List<Product> get items {
    return [..._items];
  }

  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  Future<void> fetchAndSetProducts([bool filterByUser = false]) async {
    final filterString =
        filterByUser ? 'orderBy="creatorId"&equalTo="$userId"' : '';
    var url =
        '${DotEnv().env['FIREBASE_BASE_URL']}/products.json?auth=$authToken&$filterString';
    try {
      final response = await http.get(url);
      final extractedData = json.decode(response.body);
      if (extractedData == null) return;

      url =
          '${DotEnv().env['FIREBASE_BASE_URL']}/userFavorites/$userId.json?auth=$authToken';
      final favoriteResponse = await http.get(url);
      final favoriteData = json.decode(favoriteResponse.body);
      final List<Product> loadedProduts = [];
      extractedData.forEach((id, product) {
        loadedProduts.add(
          Product(
            id: id,
            title: product['title'],
            description: product['description'],
            price: product['price'],
            imageUrl: product['imageURL'],
            isFavorite:
                favoriteData == null ? false : favoriteData[id] ?? false,
          ),
        );
      });
      _items = loadedProduts;
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> addProduct(Product product) async {
    final url =
        '${DotEnv().env['FIREBASE_BASE_URL']}/products.json?auth=$authToken';
    try {
      final response = await http.post(
        url,
        body: json.encode({
          'title': product.title,
          'description': product.description,
          'imageURL': product.imageUrl,
          'price': product.price,
          'isFavorite': product.isFavorite,
          'creatorId': userId
        }),
      );
      final newProduct = Product(
          id: json.decode(response.body)['name'],
          title: product.title,
          price: product.price,
          description: product.description,
          imageUrl: product.imageUrl);
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      throw error;
    }
  }

  Future<void> updateProduct(String id, Product product) async {
    final productIndex = _items.indexWhere((p) => p.id == id);
    if (productIndex >= 0) {
      final url =
          '${DotEnv().env['FIREBASE_BASE_URL']}/products/$id.json?auth=$authToken';
      await http.patch(url,
          body: json.encode({
            'title': product.title,
            'description': product.description,
            'price': product.price,
            'imageURL': product.imageUrl,
          }));
      _items[productIndex] = product;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    final url =
        '${DotEnv().env['FIREBASE_BASE_URL']}/products/$id.json?auth=$authToken';
    final productIndex = _items.indexWhere((product) => product.id == id);
    var deleteProduct = _items[productIndex];
    _items.removeAt(productIndex);
    notifyListeners();
    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      _items.insert(productIndex, deleteProduct);
      notifyListeners();
      throw HttpException('Could not delete product!');
    }
    deleteProduct = null;
  }
}
