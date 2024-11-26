import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChooseGroupImageScreen extends StatefulWidget {
  final String? currentImage;
  final Function(dynamic) onImageSelected;

  const ChooseGroupImageScreen({
    Key? key,
    required this.onImageSelected,
    this.currentImage,
  }) : super(key: key);

  @override
  State<ChooseGroupImageScreen> createState() => _ChooseGroupImageScreenState();
}

class _ChooseGroupImageScreenState extends State<ChooseGroupImageScreen> {
  final ImagePicker _picker = ImagePicker();

  final List<String> defaultImages = [
    'assets/group_images/default1.png',
    'assets/group_images/default2.png',
    'assets/group_images/default3.png',
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        if (await imageFile.exists()) {
          widget.onImageSelected(imageFile);
          Navigator.pop(context, imageFile);
        } else {
          throw Exception('Selected image file not found');
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5217),
        title: const Text(
          'Choose Group Image',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose from gallery or camera',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFF0C5217),
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: Text('Choose from Gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFF0C5217),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: Text('Take a Photo'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Default Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: defaultImages.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    widget.onImageSelected(defaultImages[index]);
                    Navigator.pop(context, defaultImages[index]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        defaultImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.error, color: Colors.red),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}