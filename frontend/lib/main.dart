import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class ImageDisplay extends StatelessWidget {
  final File imageFile;

  const ImageDisplay({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define a maximum height for the image, e.g., 50% of the screen height
    final maxImageHeight = screenHeight * 0.5;
    // Or define a maximum width, or both
    final maxImageWidth = screenWidth * 0.8;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxImageWidth,
          maxHeight: maxImageHeight,
        ),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain, // Still use BoxFit to scale within the constraints
          errorBuilder: (context, error, stackTrace) {
            return const Text('Could not load image.');
          },
        ),
      ),
    );
  }
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

class _ImagePickerPageState extends State<ImagePickerPage>
    with SingleTickerProviderStateMixin {
  final picker = ImagePicker();
  File? _image;
  Map<String, dynamic>? _predictionData; // Store the entire prediction data
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Check and request permissions
  Future<void> _checkPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
    ].request();
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _predictionData = null; // Clear previous results
      });

      _classifyImage(_image!);
    } else {
      print("No image selected.");
    }
  }

  // Send image to server and get classification result
  Future<void> _classifyImage(File image) async {
    final uri = Uri.parse('http://10.0.2.2:8099/predict/'); // Update with your server IP

    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    print("Raw Response from server: $responseBody"); // Debugging

    if (response.statusCode == 200) {
      try {
        Map<String, dynamic> data = jsonDecode(responseBody); // Decode as a Map
        print("Parsed Response: $data"); // Debugging

        setState(() {
          _predictionData = data; // Store the entire response data
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
        bottom: _predictionData != null
            ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Caption'),
            Tab(text: 'Predictions'),
          ],
        )
            : null, // Don't show tabs if no prediction data
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _image == null
                  ? SizedBox(
                  height: 200,
                  child: Center(child: Text("No image selected.")))
                  : ImageDisplay(imageFile: _image!),
            ),
            if (_predictionData != null)
              SizedBox(
                height: 300, // Adjust height as needed for the TabBarView
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Simple Caption (assuming your server returns a "caption" field)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _predictionData?["caption"] ?? "No caption available.",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    // Tab 2: List of Predictions
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _predictionData?["predictions"] != null &&
                          _predictionData!["predictions"] is List
                          ? ListView.builder(
                        itemCount: (_predictionData!["predictions"] as List)
                            .length,
                        itemBuilder: (context, index) {
                          final prediction = (_predictionData!["predictions"]
                          as List)[index];
                          return ListTile(
                            title: Text(
                              prediction["label"] ?? "Label not found",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              prediction["confidence"] != null
                                  ? "Confidence: ${(prediction["confidence"] * 100).toStringAsFixed(2)}%"
                                  : "Confidence not available",
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        },
                      )
                          : const Text("No predictions available."),
                    ),
                  ],
                ),
              ),
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
            SizedBox(height: 20), // Add some spacing at the bottom
          ],
        ),
      ),
    );
  }
}