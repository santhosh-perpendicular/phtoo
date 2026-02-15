import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const UploadScreen(),
    );
  }
}

/* ================= UPLOAD SCREEN ================= */

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<XFile> selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImages() async {
    try {
      if (kIsWeb) {
        final images = await _picker.pickMultiImage();
        setState(() => selectedImages = images);
      } else if (Platform.isAndroid || Platform.isIOS) {
        final images = await _picker.pickMultiImage();
        setState(() => selectedImages = images);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );

        if (result != null) {
          setState(() {
            selectedImages = result.paths
                .whereType<String>()
                .map((path) => XFile(path))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Pick error: $e");
    }
  }

  void goToProcessing() {
    if (selectedImages.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(images: selectedImages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UPLOAD PHOTOS")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: pickImages,
            child: const Text("SELECT FILES"),
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
                final image = selectedImages[index];

                if (kIsWeb) {
                  return FutureBuilder(
                    future: image.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return const Center(
                          child: CircularProgressIndicator());
                    },
                  );
                } else {
                  return Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                  );
                }
              },
            ),
          ),
          if (selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: goToProcessing,
                child: const Text("UPLOAD & RANK"),
              ),
            ),
        ],
      ),
    );
  }
}

/* ================= PROCESSING SCREEN ================= */

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
          await http.MultipartFile.fromPath(
            'files',
            img.path,
          ),
        );
      }

      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List results = decoded['results'];

        // Sort by score (highest first)
        results.sort((a, b) =>
            (b['score'] as num).compareTo(a['score'] as num));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(results: results),
          ),
        );
      } else {
        showError("Server Error ${response.statusCode}");
      }
    } catch (e) {
      showError("Upload Failed: $e");
    }
  }

  String getBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000/upload-images';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/upload-images';
    } else {
      return 'http://localhost:8000/upload-images';
    }
  }

  void showError(String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/* ================= RESULT SCREEN ================= */

class ResultScreen extends StatelessWidget {
  final List results;

  const ResultScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RANKED PHOTOS")),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];

          return ListTile(
            leading: CircleAvatar(
              child: Text("#${index + 1}"),
            ),
            title: Text(item['filename']),
            subtitle:
                Text("Score: ${item['score'].toStringAsFixed(2)}"),
          );
        },
      ),
    );
  }
}
