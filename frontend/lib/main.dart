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

class _ImagePickerPageState extends State<ImagePickerPage>
    with SingleTickerProviderStateMixin {
  final picker = ImagePicker();
  File? _image;
  Map<String, dynamic>? _predictionData;
  late TabController _tabController;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
    ].request();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _predictionData = null;
      });
    } else {
      print("No image selected.");
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null) return;

    final uri = Uri.parse('http://10.0.2.2:8099/predict/'); // Replace with your server IP

    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
    request.fields['tags'] = jsonEncode(_tags);

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    print("Raw Response from server: $responseBody");

    if (response.statusCode == 200) {
      try {
        Map<String, dynamic> data = jsonDecode(responseBody);
        print("Parsed Response: $data");

        setState(() {
          _predictionData = data;
        });
      } catch (e) {
        print("Error parsing JSON: $e");
      }
    } else {
      print("Error: ${response.statusCode}");
    }
  }

  void _addTag() {
    String tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
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
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: _image == null
                  ? Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(child: Text("No image selected.")),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(
                  _image!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text('Could not load image.');
                  },
                ),
              ),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _tags
                  .map((tag) => Chip(
                label: Text(tag),
                onDeleted: () => _removeTag(tag),
              ))
                  .toList(),
            ),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: 'Add tags (location, context)',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addTag,
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library, color: Colors.white),
                    label: Text("Gallery", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    label: Text("Camera", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                    onPressed: _classifyImage,
                    icon: Icon(Icons.send, color: Colors.white), // Added Icon
                    label: Text("Send", style: TextStyle(color: Colors.white)), //Added style
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, // Change color as needed
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),

                ),
                ),
              ),
            if (_predictionData != null)
              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _predictionData?["caption"] ?? "No caption available.",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
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
          ],
        ),
      ),
    );
  }}