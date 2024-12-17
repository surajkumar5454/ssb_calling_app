import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class DatabaseHelper {
  static Database? _database;
  static Database? _logsDatabase;
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> get logsDatabase async {
    if (_logsDatabase != null) return _logsDatabase!;
    _logsDatabase = await _initLogsDatabase();
    return _logsDatabase!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = await getDatabasesPath();
      String fullPath = join(path, 'pims.db');
      print('Looking for pims database at: $fullPath');

      // Add a retry mechanism
      int maxRetries = 3;
      for (int i = 0; i < maxRetries; i++) {
        if (await databaseExists(fullPath)) {
          print('Found pims.db at $fullPath');
          try {
            // Open the database with specific flags to prevent version pragma
            final db = await openDatabase(
              fullPath,
              readOnly: true,
              singleInstance: true,
              onConfigure: (db) async {
                // Disable version tracking
                await db.execute('PRAGMA foreign_keys = OFF');
              },
              onCreate: null, // Prevent database creation
              onUpgrade: null, // Prevent upgrade
              onDowngrade: null, // Prevent downgrade
              version: null, // Don't set version
            );

            // Verify database is accessible with a simple query on parmanentinfo table
            try {
              await db.query('parmanentinfo', limit: 1);
              print('Pims database verified successfully');
              return db;
            } catch (e) {
              print('Error verifying database: $e');
              await db.close();
              throw e;
            }
          } catch (e) {
            print('Attempt ${i + 1}: Error accessing database: $e');
            if (i == maxRetries - 1) {
              throw Exception('Failed to access database after $maxRetries attempts');
            }
            await Future.delayed(Duration(seconds: 1)); // Wait before retrying
          }
        } else {
          print('Attempt ${i + 1}: Database not found, waiting...');
          if (i == maxRetries - 1) {
            throw Exception('Database not found after $maxRetries attempts. Please copy pims.db to: $fullPath');
          }
          await Future.delayed(Duration(seconds: 1)); // Wait before retrying
        }
      }

      throw Exception('Failed to initialize database'); // Should never reach here
    } catch (e) {
      print('Error initializing pims database: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<Database> _initLogsDatabase() async {
    try {
      String path = await getDatabasesPath();
      String fullPath = join(path, 'call_logs.db');
      print('Initializing logs database at: $fullPath');

      // Make sure the directory exists
      await Directory(dirname(fullPath)).create(recursive: true);

      final db = await openDatabase(
        fullPath,
        version: 1,
        onCreate: (Database db, int version) async {
          print('Creating call logs table...');
          await db.execute('''
            CREATE TABLE call_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              phone_number TEXT NOT NULL,
              timestamp INTEGER NOT NULL
            )
          ''');
          print('Call logs table created successfully');
        },
        onOpen: (db) {
          print('Logs database opened successfully');
        },
      );

      // Verify database is accessible
      try {
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM call_logs'));
        print('Logs database verified - found $count entries');
      } catch (e) {
        print('Error verifying logs database: $e');
        await db.close();
        await File(fullPath).delete();
        print('Deleted corrupted logs database, will retry initialization');
        return await _initLogsDatabase();
      }

      return db;
    } catch (e) {
      print('Error initializing logs database: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getContactByPhoneNumber(String phoneNumber) async {
    try {
      final db = await database;
      
      // Process the phone number
      phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), ''); // Remove whitespace
      if (phoneNumber.startsWith('+91')) {
        phoneNumber = phoneNumber.substring(3); // Remove +91 prefix
      }
      // Get last 10 digits
      phoneNumber = phoneNumber.substring(max(0, phoneNumber.length - 10));
      
      print('Searching for processed number: $phoneNumber');

      // First get the uidno from parmanentinfo table checking both mobno and homephone
      final List<Map<String, dynamic>> uidResults = await db.rawQuery('''
        SELECT uidno 
        FROM parmanentinfo 
        WHERE trim(mobno) = ? OR trim(homephone) = ?
        LIMIT 1
      ''', [phoneNumber, phoneNumber]);

      if (uidResults.isEmpty) {
        print('No uidno found for number: $phoneNumber');
        return null;
      }

      final String uidno = uidResults.first['uidno'].toString().trim();
      print('Found uidno: $uidno');

      // Get detailed info using the join query
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT 
          p.uidno,
          p.name,
          p.mobno,
          p.homephone,
          j.rank as rank_cd,
          j.branch as branch_cd,
          j.unit as unit_cd,
          u.unit_nm,
          r.rnk_nm,
          r.brn_nm
        FROM 
          parmanentinfo p
        JOIN 
          joininfo j ON p.uidno = j.uidno
        JOIN 
          unitdep u ON j.unit = u.unit_cd
        JOIN 
          rnk_brn_mas r ON j.rank = r.rnk_cd AND j.branch = r.brn_cd
        WHERE 
          j.uidno = ? 
        ORDER BY 
          j.dateofjoin DESC
        LIMIT 1
      ''', [uidno]);

      print('Query results: $results');

      if (results.isNotEmpty) {
        final info = results.first;
        print('Found detailed info: $info');
        return {
          'uidno': info['uidno']?.toString().trim(),
          'name': info['name']?.toString().trim(),
          'unit': info['unit_nm']?.toString().trim(),
          'rank': info['rnk_nm']?.toString().trim(),
          'branch': info['brn_nm']?.toString().trim(),
          'mobno': info['mobno']?.toString().trim(),
          'homephone': info['homephone']?.toString().trim(),
          'rank_cd': info['rank_cd']?.toString().trim(),
          'branch_cd': info['branch_cd']?.toString().trim(),
          'unit_cd': info['unit_cd']?.toString().trim(),
        };
      } else {
        print('No detailed info found for uidno: $uidno');
        // If no detailed info found, get basic info from parmanentinfo
        final List<Map<String, dynamic>> basicInfo = await db.query(
          'parmanentinfo',
          columns: ['uidno', 'name'],
          where: 'uidno = ?',
          whereArgs: [uidno],
          limit: 1,
        );

        if (basicInfo.isNotEmpty) {
          return {
            'uidno': basicInfo.first['uidno']?.toString().trim(),
            'name': basicInfo.first['name']?.toString().trim(),
            'unit': 'Unknown Unit',
            'rank': 'Unknown Rank',
            'branch': 'Unknown Branch'
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting contact: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  Future<void> logCall(String phoneNumber) async {
    try {
      final db = await logsDatabase;
      
      await db.insert('call_logs', {
        'phone_number': phoneNumber,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error logging call: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<List<Map<String, dynamic>>> getCallLogs() async {
    try {
      final logsDb = await logsDatabase;
      final contactsDb = await database;
      
      // Get call logs
      final List<Map<String, dynamic>> logs = await logsDb.query(
        'call_logs',
        orderBy: 'timestamp DESC',
        limit: 100
      );

      // Enrich logs with contact information
      List<Map<String, dynamic>> enrichedLogs = [];
      for (var log in logs) {
        final phoneNumber = log['phone_number'] as String;
        final contactInfo = await getContactByPhoneNumber(phoneNumber);

        enrichedLogs.add({
          'id': log['id'],
          'phone_number': phoneNumber,
          'timestamp': log['timestamp'], // Keep as integer timestamp
          'name': contactInfo?['name']?.toString().trim() ?? 'Unknown',
          'unit': contactInfo?['unit']?.toString().trim() ?? 'Unknown Unit',
          'rank': contactInfo?['rank']?.toString().trim() ?? 'Unknown Rank',
          'branch': contactInfo?['branch']?.toString().trim() ?? 'Unknown Branch',
        });
      }

      return enrichedLogs;
    } catch (e) {
      print('Error getting call logs: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }
}
