import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImagePickerPage(),
    );
  }
}

class ImagePickerPage extends StatefulWidget {
  @override
  _ImagePickerPageState createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<ImagePickerPage> {
  final picker = ImagePicker();
  File? _image;
  List<Map<String, dynamic>> _results = []; // Store parsed response data

  // Check and request permissions
  Future<void> _checkPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
    ].request();
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    await _checkPermissions();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _results.clear(); // Clear previous results
      });

      _classifyImage(_image!);
    } else {
      print("No image selected.");
    }
  }

  // Send image to server and get classification result
  Future<void> _classifyImage(File image) async {
    final uri = Uri.parse('http://13.60.229.68:8099/predict/'); // Update with your server IP

    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    print("Raw Response from server: $responseBody"); // Debugging

    if (response.statusCode == 200) {
      try {
        Map<String, dynamic> data = jsonDecode(responseBody);  // Decode as a Map
        print("Parsed Response: $data"); // Debugging

        setState(() {
          _results = List<Map<String, dynamic>>.from(data["predictions"]); // Extract predictions list
        });
      } catch (e) {
        print("Error parsing JSON: $e");
      }
    } else {
      print("Error: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Image Classification"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _image == null
              ? Text("No image selected.")
              : Image.file(_image!), // Display picked image
          SizedBox(height: 20),
          _results.isNotEmpty
              ? Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _results[index]["label"],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Confidence: ${(_results[index]["confidence"] * 100).toStringAsFixed(2)}%",
                    style: TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
          )
              : Text("No predictions yet."),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _pickImage(ImageSource.gallery);
            },
            child: Text("Pick from Gallery"),
          ),
          ElevatedButton(
            onPressed: () {
              _pickImage(ImageSource.camera);
            },
            child: Text("Pick from Camera"),
          ),
        ],
      ),
    );
  }
}
