import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PhotoSelectorApp());
}

/* ------------------- APP ------------------- */
class PhotoSelectorApp extends StatelessWidget {
  const PhotoSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "PhotoSelector",
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFFFFD600),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFFFD600),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD600),
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

/* ------------------- LOGIN SCREEN ------------------- */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD600),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD600).withAlpha(80),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "LOGIN",
                style: TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),

              // Username
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Username",
                  labelStyle: const TextStyle(color: Color(0xFFFFD600)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFFFD600)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Color(0xFFFFD600)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFFFD600)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Enter Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UploadScreen(),
                      ),
                    );
                  },
                  child: const Text("ENTER"),
                ),
              ),
            ],
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
  List<XFile> selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImages() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final images = await _picker.pickMultiImage();
        setState(() {
          selectedImages = images;
        });
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null && result.paths.isNotEmpty) {
          setState(() {
            selectedImages = result.paths
                .whereType<String>()
                .map((path) => XFile(path))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
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
          Text(
            "FILES SELECTED: ${selectedImages.length}",
            style: const TextStyle(color: Color(0xFFFFD600)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFD600)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(selectedImages[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: goToProcessing,
                child: const Text("UPLOAD & ANALYZE"),
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
  List<dynamic> results = [];

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
        request.files.add(await http.MultipartFile.fromPath('files', img.path));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = jsonDecode(respStr);
        setState(() {
          results = data['results'];
        });
      } else {
        showError("Server Error: ${response.statusCode}");
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: results.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600)))
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                var item = results[index];
                return ListTile(
                  title: Text(
                    item['filename'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    item['score'].toString(),
                    style: const TextStyle(color: Color(0xFFFFD600)),
                  ),
                );
              },
            ),
    );
  }
}
