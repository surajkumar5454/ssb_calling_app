import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../helpers/image_database_helper.dart'; // Import ImageDatabaseHelper

class ContactDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> contact;

  const ContactDetailsScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.contact['uidno'] != null) {
      try {
        final imageDatabaseHelper = ImageDatabaseHelper();
        final imageBytes = await imageDatabaseHelper.getImageByUidno(
          int.parse(widget.contact['uidno'].toString()),
        );
        if (mounted) {
          setState(() {
            _imageBytes = imageBytes;
          });
        }
      } catch (e) {
        print('Error loading image: $e');
      }
    }
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: PhotoView(
                  imageProvider: MemoryImage(_imageBytes!),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF2C3E50),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _imageBytes != null
                        ? () => _showFullScreenImage(context)
                        : null,
                    child: Hero(
                      tag: 'contact_image',
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[300],
                          image: _imageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageBytes == null
                            ? const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.contact['name']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoTile(
                    'Rank',
                    widget.contact['rank']?.toString() ?? 'Not Available',
                    Icons.military_tech,
                  ),
                  _buildInfoTile(
                    'Branch',
                    widget.contact['branch']?.toString() ?? 'Not Available',
                    Icons.account_tree,
                  ),
                  _buildInfoTile(
                    'Unit',
                    widget.contact['unit']?.toString() ?? 'Not Available',
                    Icons.business,
                  ),
                  _buildInfoTile(
                    'UID',
                    widget.contact['uidno']?.toString() ?? 'Not Available',
                    Icons.badge,
                  ),
                  if (widget.contact['mobno'] != null)
                    _buildInfoTile(
                      'Mobile',
                      widget.contact['mobno'].toString(),
                      Icons.phone_android,
                    ),
                  if (widget.contact['homephone'] != null)
                    _buildInfoTile(
                      'Home Phone',
                      widget.contact['homephone'].toString(),
                      Icons.phone,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF2C3E50)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
