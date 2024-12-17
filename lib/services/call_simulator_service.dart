import 'package:flutter/services.dart';

class CallSimulatorService {
  static const platform = MethodChannel('com.example.caller_app/phone_state');
  
  Future<void> simulateIncomingCall(String phoneNumber) async {
    try {
      print('Attempting to simulate call for number: $phoneNumber'); // Debug log
      await platform.invokeMethod('simulateIncomingCall', {
        'phoneNumber': phoneNumber
      });
      print('Call simulation request sent successfully'); // Debug log
    } catch (e) {
      print('Error in call simulation: $e'); // Debug log
      rethrow;
    }
  }
}
