import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ImageDatabaseHelper {
  static final ImageDatabaseHelper _instance = ImageDatabaseHelper._internal();
  static Database? _database;
  static const String dbName = 'images_resize.db';

  factory ImageDatabaseHelper() => _instance;

  ImageDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, dbName);
    print('Image database path: $path');

    // Check if database exists in local storage
    if (await File(path).exists()) {
      print('Image database found in local storage');
      return await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
    } else {
      print('Image database not found. Please copy images_resize.db to: $path');
      throw Exception('Image database not found. Please copy images_resize.db to: $path');
    }
  }

  Future<Uint8List?> getImageByUidno(int uidno) async {
    print('ImageDatabaseHelper: Querying image for UID: $uidno');
    try {
      final db = await database;
      print('ImageDatabaseHelper: Database connection established');
      
      final List<Map<String, dynamic>> results = await db.query(
        'images',
        columns: ['image'],
        where: 'uidno = ?',
        whereArgs: [uidno],
        limit: 1,
      );

      print('ImageDatabaseHelper: Query results: ${results.length} rows found');
      
      if (results.isNotEmpty && results.first['image'] != null) {
        final imageData = results.first['image'] as Uint8List;
        print('ImageDatabaseHelper: Image found, size: ${imageData.length} bytes');
        return imageData;
      }
      print('ImageDatabaseHelper: No image found for UID: $uidno');
      return null;
    } catch (e) {
      print('ImageDatabaseHelper: Error getting image from database: $e');
      return null;
    }
  }
}
