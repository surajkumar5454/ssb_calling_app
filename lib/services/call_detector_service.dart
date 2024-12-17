import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';
import '../helpers/database_helper.dart';
import '../helpers/image_database_helper.dart';
import 'package:flutter/services.dart';
import 'package:caller_app/screens/contact_details_screen.dart';

class CallDetectorService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImageDatabaseHelper _imageDatabaseHelper = ImageDatabaseHelper();
  bool _isInitialized = false;
  static OverlaySupportEntry? _currentNotification;
  
  static const platform = MethodChannel('com.example.caller_app/phone_state');
  static final CallDetectorService _instance = CallDetectorService._internal();
  
  factory CallDetectorService() => _instance;

  CallDetectorService._internal() {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request necessary permissions
      final phoneStatus = await Permission.phone.request();
      final notificationStatus = await Permission.notification.request();
      
      if (!phoneStatus.isGranted || !notificationStatus.isGranted) {
        throw Exception('Required permissions not granted');
      }
      
      // Request overlay permission if not granted
      if (!await Permission.systemAlertWindow.isGranted) {
        final status = await Permission.systemAlertWindow.request();
        if (!status.isGranted) {
          print('Overlay permission not granted');
          // Try requesting through settings
          if (await openAppSettings()) {
            // Wait for user to potentially grant permission
            await Future.delayed(const Duration(seconds: 2));
            if (!await Permission.systemAlertWindow.isGranted) {
              throw Exception('Overlay permission denied');
            }
          } else {
            throw Exception('Could not open app settings');
          }
        }
      }

      // Initialize platform side
      await platform.invokeMethod('initialize');
      
      _isInitialized = true;
      print('Call detector initialized successfully');
    } catch (e) {
      print('Failed to initialize call detector: $e');
      rethrow;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onIncomingCall':
        final String phoneNumber = call.arguments as String;
        await onIncomingCall(phoneNumber);
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  Future<Uint8List?> _getCallerImage(String uidno) async {
    print('Attempting to load image for UID: $uidno');
    try {
      final imageData = await _imageDatabaseHelper.getImageByUidno(int.parse(uidno));
      if (imageData != null) {
        print('Successfully loaded image for UID: $uidno (${imageData.length} bytes)');
        return imageData;
      } else {
        print('No image found for UID: $uidno');
      }
      return null;
    } catch (e) {
      print('Error loading image for UID $uidno: $e');
      return null;
    }
  }

  // This method will be called by the platform through the method channel
  Future<void> onIncomingCall(String phoneNumber) async {
    try {
      // Log the call
      await _databaseHelper.logCall(phoneNumber);

      // Check if overlay permission is granted
      if (!await Permission.systemAlertWindow.isGranted) {
        print('Overlay permission not granted');
        return;
      }

      // Dismiss any existing notification
      _currentNotification?.dismiss();

      final callerInfo = await _databaseHelper.getContactByPhoneNumber(phoneNumber);
      
      if (callerInfo != null) {
        print('Found caller info: $callerInfo');
        
        // Load image if uidno is available
        Uint8List? imageBytes;
        if (callerInfo['uidno'] != null) {
          imageBytes = await _imageDatabaseHelper.getImageByUidno(int.parse(callerInfo['uidno'].toString()));
        }

        _currentNotification = showOverlayNotification(
          (context) {
            return Container(
              margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  OverlaySupportEntry.of(context)?.dismiss();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactDetailsScreen(
                        contactInfo: {...callerInfo, 'phone': phoneNumber},
                        imageBytes: imageBytes,
                      ),
                    ),
                  );
                },
                onPanUpdate: (details) {
                  if (details.delta.dx.abs() > 3) {
                    OverlaySupportEntry.of(context)?.dismiss();
                  }
                },
                child: Card(
                  color: const Color(0xFF2C3E50),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                                image: imageBytes != null
                                    ? DecorationImage(
                                        image: MemoryImage(imageBytes),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageBytes == null
                                  ? Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    callerInfo['name']?.toString() ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${callerInfo['rank'] ?? 'Unknown Rank'} - ${callerInfo['branch'] ?? 'Unknown Branch'}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          duration: const Duration(seconds: 10),
          position: NotificationPosition.top,
          key: Key(DateTime.now().toString()),
        );
      } else {
        print('No caller info found for number: $phoneNumber');
        // Show a simple notification for unknown numbers
        _currentNotification = showOverlayNotification(
          (context) {
            return Container(
              margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.dx.abs() > 3) {
                    OverlaySupportEntry.of(context)?.dismiss();
                  }
                },
                child: Card(
                  color: const Color(0xFF2C3E50),
                  child: ListTile(
                    leading: Icon(
                      Icons.phone_in_talk,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    title: Text(
                      'Incoming Call',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      phoneNumber,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          duration: const Duration(seconds: 3),
          position: NotificationPosition.top,
        );
      }
    } catch (e) {
      print('Error handling incoming call: $e');
    }
  }

  Widget _buildInfoColumn(String label, String? value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
