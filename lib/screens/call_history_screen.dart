import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../helpers/database_helper.dart';
import '../helpers/image_database_helper.dart';
import '../services/call_simulator_service.dart';
import 'contact_details_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({Key? key}) : super(key: key);

  @override
  _CallHistoryScreenState createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CallSimulatorService _callSimulator = CallSimulatorService();

  Future<void> _simulateIncomingCall() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulating incoming call...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      await _callSimulator.simulateIncomingCall('+1234567890');
    } catch (e) {
      print('Error details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _simulateIncomingCall,
            tooltip: 'Simulate incoming call',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _databaseHelper.getCallLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final callLogs = snapshot.data ?? [];
          if (callLogs.isEmpty) {
            return const Center(child: Text('No call history'));
          }

          return ListView.builder(
            itemCount: callLogs.length,
            itemBuilder: (context, index) {
              final call = callLogs[index];
              return CallLogTile(
                name: call['name'] ?? call['phone_number'],
                phoneNumber: call['phone_number'],
                timestamp: DateTime.fromMillisecondsSinceEpoch(call['timestamp']),
                rank: call['rank'],
                unit: call['unit'],
                branch: call['branch'],
              );
            },
          );
        },
      ),
    );
  }
}

class CallLogTile extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final DateTime timestamp;
  final String rank;
  final String unit;
  final String branch;

  const CallLogTile({
    Key? key,
    required this.name,
    required this.phoneNumber,
    required this.timestamp,
    required this.rank,
    required this.unit,
    required this.branch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().add_jm().format(timestamp);
    final databaseHelper = DatabaseHelper();
    final imageDatabaseHelper = ImageDatabaseHelper();

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: null,
        child: Text(name[0].toUpperCase()),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$rank - $branch'),
          Text(unit),
          Text(
            formattedDate,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: Text(phoneNumber),
      isThreeLine: true,
      onTap: () async {
        final contactInfo = await databaseHelper.getContactByPhoneNumber(phoneNumber);
        if (contactInfo != null && context.mounted) {
          // Load image if uidno is available
          Uint8List? imageBytes;
          if (contactInfo['uidno'] != null) {
            imageBytes = await imageDatabaseHelper.getImageByUidno(
              int.parse(contactInfo['uidno'].toString())
            );
          }
          
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactDetailsScreen(
                  contactInfo: contactInfo,
                  imageBytes: imageBytes,
                ),
              ),
            );
          }
        }
      },
    );
  }
}
