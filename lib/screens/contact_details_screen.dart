import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ContactDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> contactInfo;
  final Uint8List? imageBytes;

  const ContactDetailsScreen({
    Key? key,
    required this.contactInfo,
    this.imageBytes,
  }) : super(key: key);

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: PhotoView(
                  imageProvider: MemoryImage(imageBytes!),
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
                    onTap: imageBytes != null
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
                          image: imageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageBytes == null
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
                    contactInfo['name']?.toString() ?? 'Unknown',
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
                    contactInfo['rank']?.toString() ?? 'Not Available',
                    Icons.military_tech,
                  ),
                  _buildInfoTile(
                    'Branch',
                    contactInfo['branch']?.toString() ?? 'Not Available',
                    Icons.account_tree,
                  ),
                  _buildInfoTile(
                    'Unit',
                    contactInfo['unit']?.toString() ?? 'Not Available',
                    Icons.business,
                  ),
                  _buildInfoTile(
                    'UID',
                    contactInfo['uidno']?.toString() ?? 'Not Available',
                    Icons.badge,
                  ),
                  _buildInfoTile(
                    'Phone',
                    contactInfo['phone']?.toString() ?? 'Not Available',
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
          Column(
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
        ],
      ),
    );
  }
}
