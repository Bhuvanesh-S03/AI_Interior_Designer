import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'ai_design.dart'; // ✅ Make sure this file exists

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imageFile;
  bool _isLoading = false;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<String?> _uploadImageToImgbb() async {
    if (_imageFile == null || !_imageFile!.existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No valid image selected')));
      return null;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final apiKey = '274ee2d6f4ef4b7afa24b13d21ffdfc3'; // ✅ Your API key

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
        body: {'image': base64Image, 'name': 'room_image_${Uuid().v4()}'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final imageUrl = jsonResponse['data']['url'];
        return imageUrl;
      } else {
        print('Upload failed: ${response.body}');
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      return null;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Interior Designer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    _imageFile == null
                        ? Center(
                          child: Text(
                            'Take or select a photo of your room to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18.0),
                          ),
                        )
                        : Image.file(_imageFile!, fit: BoxFit.contain),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (_imageFile != null)
                ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            final url = await _uploadImageToImgbb();
                            if (url != null) {
                              setState(() {
                                _imageUrl = url;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Image uploaded successfully!'),
                                ),
                              );

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AIDesignScreen(designStyle: designStyle, roomType: roomType),
                                ),
                              );
                            }
                          },
                  child:
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Analyze Room'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              SizedBox(height: 20),
              if (_imageUrl != null)
                Text(
                  'Uploaded Image URL: $_imageUrl',
                  style: TextStyle(fontSize: 16, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
