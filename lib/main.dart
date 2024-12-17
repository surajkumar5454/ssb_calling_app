import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/call_detector_service.dart';
import 'helpers/database_helper.dart';
import 'screens/call_history_screen.dart';
import 'screens/search_number_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database early
  try {
    print('Checking database availability...');
    final db = DatabaseHelper();
    
    // Add a small delay before first database access
    await Future.delayed(Duration(milliseconds: 500));
    
    await db.database; // This will throw an exception if pims.db is not found
    await db.logsDatabase;
    print('Databases initialized successfully');

    // Initialize call detector service
    final callDetector = CallDetectorService();
    await callDetector.initialize();
    print('Call detector service initialized successfully');
  } catch (e) {
    print('Initialization error: $e');
    // We'll show this error in the UI
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'Caller App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50)),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Caller App'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final CallDetectorService _callDetectorService = CallDetectorService();
  final TextEditingController _phoneController = TextEditingController();
  bool _isInitialized = false;
  String _initializationError = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!_isInitialized) {
      try {
        print('Starting app initialization...');

        // Check database again
        final db = DatabaseHelper();
        try {
          await db.database;
          print('Database access verified');
        } catch (e) {
          setState(() {
            _initializationError = 'Database not found. Please copy pims.db to the correct location.';
          });
          return;
        }
        
        // Request permissions with proper error handling
        print('Requesting permissions...');
        Map<Permission, PermissionStatus> statuses = await [
          Permission.phone,
          Permission.notification,
          Permission.systemAlertWindow,
        ].request();

        // Check if any permission was denied
        bool anyDenied = statuses.values.any(
          (status) => status.isDenied || status.isPermanentlyDenied
        );

        if (anyDenied) {
          print('Some permissions were denied');
          setState(() {
            _initializationError = 'Required permissions were denied. Please grant permissions in settings.';
          });
          return;
        }
        print('All permissions granted');

        setState(() {
          _isInitialized = true;
          _initializationError = '';
        });
        print('App initialization completed successfully');
      } catch (e, stackTrace) {
        print('Error initializing app: $e');
        print('Stack trace: $stackTrace');
        setState(() {
          _initializationError = 'Error initializing app: $e';
        });
      }
    }
  }

  Future<void> _testIncomingCall() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    try {
      await _callDetectorService.onIncomingCall(_phoneController.text);
    } catch (e) {
      print('Error simulating call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error simulating call: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF2C3E50),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.phone_in_talk,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Caller App',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Number'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchNumberScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Call History'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CallHistoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_initializationError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _initializationError,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              _isInitialized 
                ? 'App is running and listening for calls'
                : 'Initializing...',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Text(
              'Test Interface',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Enter phone number to test',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isInitialized ? _testIncomingCall : null,
              child: const Text('Simulate Incoming Call'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
