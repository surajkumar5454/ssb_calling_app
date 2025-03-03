import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/image_database_helper.dart';
import 'contact_details_screen.dart';

class SearchNumberScreen extends StatefulWidget {
  const SearchNumberScreen({super.key});

  @override
  _SearchNumberScreenState createState() => _SearchNumberScreenState();
}

class _SearchNumberScreenState extends State<SearchNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImageDatabaseHelper _imageHelper = ImageDatabaseHelper();
  bool _isSearching = false;
  String? _errorMessage;

  Future<void> _searchNumber() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final contactInfo = await _databaseHelper.getContactByPhoneNumber(_phoneController.text);
      
      if (!mounted) return;

      if (contactInfo != null) {
        final uidno = contactInfo['uidno'];
        final imageBytes = uidno != null ? 
          await _imageHelper.getImageByUidno(int.parse(uidno)) : null;

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailsScreen(
              contact: contactInfo,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No contact found for this number';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching for contact: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Number'),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Enter Phone Number',
                hintText: 'e.g., +91 98765 43210',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onSubmitted: (_) => _searchNumber(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSearching ? null : _searchNumber,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2C3E50),
              ),
              child: _isSearching
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Search',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
