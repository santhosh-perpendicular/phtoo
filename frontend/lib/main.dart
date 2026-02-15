import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PhotoSelectorApp());
}

class PhotoSelectorApp extends StatelessWidget {
  const PhotoSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UploadScreen(),
    );
  }
}

/* ------------------- UPLOAD SCREEN ------------------- */

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<XFile> selectedImages = [];

  Future<void> pickImages() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      setState(() {
        selectedImages = images;
      });
    } else if (Platform.isWindows) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          selectedImages = result.files
              .map((file) => XFile(file.path!))
              .toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Photo Selector")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: pickImages,
            child: const Text("Select Photos"),
          ),
          const SizedBox(height: 10),
          Text("Selected: ${selectedImages.length}"),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return Image.file(
                  File(selectedImages[index].path),
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          if (selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProcessingScreen(images: selectedImages),
                    ),
                  );
                },
                child: const Text("Upload & Analyze"),
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------- PROCESSING SCREEN ------------------- */

class ProcessingScreen extends StatefulWidget {
  final List<XFile> images;

  const ProcessingScreen({super.key, required this.images});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    uploadImages();
  }

  Future<void> uploadImages() async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(getBaseUrl()),
      );

      for (var img in widget.images) {
        request.files.add(
          await http.MultipartFile.fromPath('files', img.path),
        );
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = json.decode(respStr);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              results: data["results"] ?? [],
              images: widget.images,
            ),
          ),
        );
      } else {
        showError("Server Error");
      }
    } catch (e) {
      showError("Connection Failed");
    }
  }

  String getBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/upload-images';
    } else {
      return 'http://localhost:8000/upload-images';
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/* ------------------- RESULTS SCREEN ------------------- */

class ResultsScreen extends StatelessWidget {
  final List results;
  final List<XFile> images;

  const ResultsScreen({
    super.key,
    required this.results,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ranked Results")),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          var item = results[index];

          XFile matchedImage = images.firstWhere(
            (img) => img.name == item['filename'],
            orElse: () => images[0],
          );

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: Image.file(
                File(matchedImage.path),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
              title: Text("Rank ${index + 1}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['filename']),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: (item['score'] as num) / 100,
                  ),
                  Text("Score: ${item['score']}"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
