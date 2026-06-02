import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sale.dart';

class StorageService {
  static List<Sale> _sales = [];
  static bool _loaded = false;

  static Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${dir.path}/fairwash');
    if (!await dataDir.exists()) await dataDir.create(recursive: true);
    return dataDir.path;
  }

  static Future<File> get _file async {
    final path = await _localPath;
    return File('$path/sales.json');
  }

  static Future<List<Sale>> loadSales() async {
    if (_loaded) return _sales;
    try {
      final file = await _file;
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _sales = (data as List).map((e) => Sale.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Load error: $e');
    }
    _loaded = true;
    return _sales;
  }

  static Future<void> _save() async {
    final file = await _file;
    await file.writeAsString(jsonEncode(_sales.map((e) => e.toJson()).toList()));
  }

  static Future<void> addSale(Sale sale) async {
    _sales.add(sale);
    await _save();
  }

  static Future<List<Sale>> getSales() async {
    if (!_loaded) await loadSales();
    return _sales;
  }

  static Future<String> copyImage(String sourcePath) async {
    try {
      final path = await _localPath;
      final ext = sourcePath.split('.').last;
      final name = DateTime.now().millisecondsSinceEpoch.toString();
      final dest = '$path/$name.$ext';
      await File(sourcePath).copy(dest);
      return dest;
    } catch (e) {
      return sourcePath;
    }
  }
}
