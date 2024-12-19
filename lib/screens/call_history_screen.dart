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
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadMoreLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final newLogs = await _databaseHelper.getCallLogs(
        offset: _currentPage * _pageSize,
        limit: _pageSize,
      );

      setState(() {
        if (newLogs.isEmpty) {
          _hasMoreData = false;
        } else {
          _callLogs.addAll(newLogs);
          _currentPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load call logs. Please try again.';
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreLogs();
    }
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _callLogs.clear();
      _currentPage = 0;
      _hasMoreData = true;
      _hasError = false;
      _errorMessage = '';
    });
    await _loadMoreLogs();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshLogs,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLogs,
        child: _hasError
            ? _buildErrorWidget()
            : _callLogs.isEmpty && !_isLoading
                ? const Center(child: Text('No call history'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _callLogs.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _callLogs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final call = _callLogs[index];
                      return CallLogTile(
                        name: call['name'] ?? 'Unknown',
                        phoneNumber: call['phone_number'],
                        timestamp: DateTime.fromMillisecondsSinceEpoch(
                            call['timestamp']),
                        rank: call['rank'],
                        unit: call['unit'],
                        branch: call['branch'],
                      );
                    },
                  ),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
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
          final contactInfo =
              await databaseHelper.getContactByPhoneNumber(phoneNumber);
          if (contactInfo != null && context.mounted) {
            Uint8List? imageBytes;
            if (contactInfo['uidno'] != null) {
              imageBytes = await imageDatabaseHelper.getImageByUidno(
                int.parse(contactInfo['uidno'].toString()),
              );
            }

            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactDetailsScreen(
                    contactInfo: contactInfo,
                    imageBytes: imageBytes,
                    number: phoneNumber,
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
