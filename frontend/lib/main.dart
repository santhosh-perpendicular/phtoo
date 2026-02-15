import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PhotoSelectorApp());
}

/* ------------------- MAIN APP ------------------- */

class PhotoSelectorApp extends StatelessWidget {
  const PhotoSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        primaryColor: const Color(0xFF7C4DFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121826),
          centerTitle: true,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

/* ------------------- BACKGROUND ------------------- */

Widget darkBackground({required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF05070A),
          Color(0xFF0E1420),
          Color(0xFF1A1F2B),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: child,
  );
}

/* ------------------- LOGIN SCREEN ------------------- */

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: darkBackground(
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 60, color: Color(0xFF7C4DFF)),
                const SizedBox(height: 10),
                const Text("AI Photo Selector",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Username",
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UploadScreen()),
                      );
                    },
                    child: const Text("LOGIN"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PreviewScreen(images: images)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: darkBackground(
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload,
                    size: 60, color: Color(0xFF7C4DFF)),
                const SizedBox(height: 15),
                const Text("Upload Your Photos",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: pickImages,
                    icon: const Icon(Icons.photo),
                    label: const Text("Select Photos"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------- PREVIEW SCREEN ------------------- */

class PreviewScreen extends StatelessWidget {
  final List<XFile> images;

  const PreviewScreen({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview & Analyze")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text("Selected: ${images.length} photos"),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(images[index].path),
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProcessingScreen(images: images),
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
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/upload-images'),
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
        showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      showError("Connection Failed");
    }
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

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
