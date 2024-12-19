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
  static const String assetPath = 'assets/databases/images_resize.db';

  factory ImageDatabaseHelper() => _instance;

  ImageDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> copyDatabaseFromAssets() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, dbName);

      // Make sure the directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Check if database already exists
      final exists = await databaseExists(path);
      if (!exists) {
        print('Copying database from assets to: $path');
        
        // Copy from asset
        ByteData data = await rootBundle.load(assetPath);
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        // Write and flush the bytes to the database file
        await File(path).writeAsBytes(bytes, flush: true);
        print('Database copied successfully');
      }
    } catch (e) {
      print('Error copying database from assets: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, dbName);
      print('Image database path: $path');

      // Try to copy database from assets if it doesn't exist
      await copyDatabaseFromAssets();

      // Open the database
      return await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
    } catch (e) {
      print('Error initializing image database: $e');
      rethrow;
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
      );

      if (results.isNotEmpty && results.first['image'] != null) {
        print('ImageDatabaseHelper: Image found for UID: $uidno');
        return results.first['image'] as Uint8List;
      } else {
        print('ImageDatabaseHelper: No image found for UID: $uidno');
        return null;
      }
    } catch (e) {
      print('ImageDatabaseHelper: Error getting image: $e');
      return null;
    }
  }
}
