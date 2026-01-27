import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker picker = ImagePicker();

  Future<void> pickImages() async {
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(images: images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Photo Selector")),
      body: Center(
        child: ElevatedButton(
          onPressed: pickImages,
          child: const Text("Select Photos"),
        ),
      ),
    );
  }
}

/* ------------------- PREVIEW SCREEN ------------------- */

class PreviewScreen extends StatefulWidget {
  final List<XFile> images;
  const PreviewScreen({super.key, required this.images});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late List<XFile> images;

  @override
  void initState() {
    super.initState();
    images = List.from(widget.images);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Selected Photos")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              "Selected: ${images.length} photos",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(images[index].path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            images.removeAt(index);
                          });
                        },
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: images.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProcessingScreen(images: images),
                          ),
                        );
                      },
                child: const Text("Upload & Analyze"),
              ),
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
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://127.0.0.1:8000/upload-images'),
    );

    for (var img in widget.images) {
      request.files.add(
        await http.MultipartFile.fromPath('files', img.path),
      );
    }

    var response = await request.send();

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed")),
      );
      Navigator.pop(context);
      return;
    }

    var respStr = await response.stream.bytesToString();
    var data = json.decode(respStr);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          results: data["results"],
          images: widget.images,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Processing")),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/* ------------------- RESULTS SCREEN (SHOWS ALL RANKED PHOTOS) ------------------- */

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
    final rankedPhotos = results; // Show ALL photos, not only top 5

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranked Photos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: ListView.builder(
        itemCount: rankedPhotos.length,
        itemBuilder: (context, index) {
          var item = rankedPhotos[index];

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
                  Text("File: ${item['filename']}"),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (item['score'] as num) / 100,
                  ),
                  const SizedBox(height: 4),
                  Text("Score: ${item['score'].toStringAsFixed(1)}"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
