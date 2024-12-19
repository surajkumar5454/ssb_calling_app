import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';
import '../helpers/database_helper.dart';
import '../helpers/image_database_helper.dart';
import 'package:flutter/services.dart';
import 'package:caller_app/screens/contact_details_screen.dart';
import 'dart:convert';

class CallDetectorService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImageDatabaseHelper _imageDatabaseHelper = ImageDatabaseHelper();
  bool _isInitialized = false;
  static OverlayEntry? _overlayEntry;
  static BuildContext? _context;
  static final navigatorKey = GlobalKey<NavigatorState>();
  
  static const platform = MethodChannel('com.example.caller_app/phone_state');
  static final CallDetectorService _instance = CallDetectorService._internal();
  
  factory CallDetectorService() => _instance;

  CallDetectorService._internal() {
    _setupMethodChannel();
  }

  void setContext(BuildContext context) {
    _context = context;
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

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onIncomingCall':
          final String phoneNumber = call.arguments as String;
          await onIncomingCall(phoneNumber);
          return null;
        case 'getCallerInfo':
          final phoneNumber = call.arguments as String;
          final contact = await _databaseHelper.getContactByPhoneNumber(phoneNumber);
          print('CallDetectorService: Contact info: $contact'); // Debug log
          
          // Log the call
          await _databaseHelper.logCall(phoneNumber);
          print('CallDetectorService: Logged call for number: $phoneNumber'); // Debug log
          
          if (contact != null) {
            final callerInfo = {
              'name': contact['name'],
              'rank': contact['rank'],
              'branch': contact['brn_nm'] ?? contact['branch'],  // Try both fields
              'unit': contact['unit'],
              'uidno': contact['uidno'],
            };
            print('CallDetectorService: Sending caller info to native: $callerInfo'); // Debug log
            return callerInfo;
          }
          return null;
        case 'navigateToContact':
          final phoneNumber = call.arguments as String;
          final contact = await _databaseHelper.getContactByPhoneNumber(phoneNumber);
          if (contact != null) {
            // Add call log entry
            await _databaseHelper.logCall(phoneNumber);
            
            if (!navigatorKey.currentState!.mounted) return;
            await navigatorKey.currentState!.pushNamed(
              '/contact_details',
              arguments: contact,
            );
          }
          return null;
        default:
          throw PlatformException(
            code: 'NotImplemented',
            message: 'Method ${call.method} not implemented',
          );
      }
    } catch (e) {
      print('Error in method channel handler: $e');
      return null;
    }
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> onIncomingCall(String phoneNumber) async {
    try {
      // Check if overlay permission is granted
      if (!await Permission.systemAlertWindow.isGranted) {
        print('Overlay permission not granted');
        return;
      }

      // Remove existing overlay if any
      _overlayEntry?.remove();
      _overlayEntry = null;

      final callerInfo = await _databaseHelper.getContactByPhoneNumber(phoneNumber);
      
      // Log the call after we've checked the caller info
      await _databaseHelper.logCall(phoneNumber);
      
      if (callerInfo != null) {
        print('Found caller info: $callerInfo');
        
        // Load image if uidno is available
        Uint8List? imageBytes;
        if (callerInfo['uidno'] != null) {
          imageBytes = await _imageDatabaseHelper.getImageByUidno(int.parse(callerInfo['uidno'].toString()));
        }

        // Show overlay
        _showOverlay(
          callerInfo: callerInfo,
          phoneNumber: phoneNumber,
          imageBytes: imageBytes,
        );

        // Show high-priority notification that appears on lock screen
        await _showLockScreenNotification(
          title: 'Incoming Call',
          body: '${callerInfo['name']} (${callerInfo['rank']})\n${callerInfo['unit']}',
          phoneNumber: phoneNumber,
          callerInfo: callerInfo,
          imageBytes: imageBytes,
        );

      } else {
        print('No caller info found for number: $phoneNumber');
        _showOverlay(
          phoneNumber: phoneNumber,
        );
        
        // Show notification for unknown caller
        await _showLockScreenNotification(
          title: 'Incoming Call',
          body: 'Unknown caller: $phoneNumber',
          phoneNumber: phoneNumber,
        );
      }
    } catch (e) {
      print('Error handling incoming call: $e');
    }
  }

  Future<void> _showLockScreenNotification({
    required String title,
    required String body,
    required String phoneNumber,
    Map<String, dynamic>? callerInfo,
    Uint8List? imageBytes,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'title': title,
        'body': body,
        'id': phoneNumber.hashCode,
        'payload': callerInfo != null ? Uri.encodeFull(callerInfo.toString()) : phoneNumber,
      };

      if (imageBytes != null) {
        args['image'] = base64Encode(imageBytes);
      }

      await platform.invokeMethod('showNotification', args);

      // Auto cancel notification after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        platform.invokeMethod('cancelNotification', {'id': phoneNumber.hashCode});
      });
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  void _showOverlay({
    Map<String, dynamic>? callerInfo,
    required String phoneNumber,
    Uint8List? imageBytes,
  }) {
    if (_context == null) {
      print('Error: Context not set for overlay');
      return;
    }

    final overlayState = Overlay.of(_context!);
    if (overlayState == null) {
      print('Error: No overlay state found');
      return;
    }
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.20,
        left: 16,
        right: 16,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                if (callerInfo != null) {
                  // Remove overlay first
                  if (_overlayEntry != null) {
                    _overlayEntry?.remove();
                    _overlayEntry = null;
                  }
                  
                  // Then navigate to details screen
                  Navigator.push(
                    _context!,
                    MaterialPageRoute(
                      builder: (context) => ContactDetailsScreen(
                        contactInfo: callerInfo,
                        imageBytes: imageBytes,
                        number: phoneNumber,
                      ),
                    ),
                  );
                }
              },
              onPanUpdate: (details) {
                if (details.delta.dx.abs() > 3) {
                  _overlayEntry?.remove();
                  _overlayEntry = null;
                }
              },
              child: Card(
                color: const Color(0xFF2C3E50).withOpacity(0.95),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: callerInfo != null
                    ? _buildCallerInfoCard(callerInfo, phoneNumber, imageBytes)
                    : _buildUnknownCallerCard(phoneNumber),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
    
    // Set auto-dismiss duration based on whether caller info exists
    final dismissDuration = callerInfo != null ? 
        const Duration(seconds: 30) :  // Known contact: 30 seconds
        const Duration(seconds: 3);    // Unknown number: 3 seconds
    
    Future.delayed(dismissDuration, () {
      if (_overlayEntry != null) {  // Only dismiss if not already dismissed by tap
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  Widget _buildCallerInfoCard(
    Map<String, dynamic> callerInfo,
    String phoneNumber,
    Uint8List? imageBytes,
  ) {
    // Format phone number to show only last 10 digits
    final formattedNumber = phoneNumber.length > 10 
        ? phoneNumber.substring(phoneNumber.length - 10)
        : phoneNumber;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
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
              mainAxisSize: MainAxisSize.min,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${callerInfo['unit'] ?? 'Unknown Unit'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedNumber,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownCallerCard(String phoneNumber) {
    // Format phone number to show only last 10 digits
    final formattedNumber = phoneNumber.length > 10 
        ? phoneNumber.substring(phoneNumber.length - 10)
        : phoneNumber;

    return ListTile(
      leading: Icon(
        Icons.phone_in_talk,
        color: Colors.white.withOpacity(0.9),
        size: 32,
      ),
      title: Text(
        'Incoming Call',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      subtitle: Text(
        formattedNumber,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 16,
        ),
      ),
    );
  }
}
