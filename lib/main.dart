import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert'; // Do dekodowania CSV
import 'models.dart';
import 'package:logger/logger.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Wygenerowane przez flutterfire configure
import 'camera_screen.dart';
import 'recordings_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SkiApp());
}

class SkiApp extends StatelessWidget {
  const SkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkiCapture',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // final sensorService = SensorService();
  final model = MLModel();
  final logger = Logger();

  List<List<double>>? _csvSensorData;
  String? _predictionResult;
  String? _fileName;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    model.loadModel();
    // sensorService.startListening(_onSensorDataUpdate);
  }

  Future<void> _pickDataFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      _fileName = result.files.single.name;
      List<List<double>> loadedData = [];

      try {
        final lines = await file.readAsLines();
        for (var i = 1; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length >= 12) {
            List<double> row = parts.sublist(0, 12).map((s) => double.tryParse(s) ?? 0.0).toList();
            loadedData.add(row);
          }
        }
        setState(() {
          _csvSensorData = loadedData;
          _predictionResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wczytano ${_csvSensorData!.length} wierszy danych z $_fileName')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd wczytywania pliku CSV: $e')),
        );
      }
    }
  }

  Future<void> _performInference() async {
    if (_csvSensorData == null || _csvSensorData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw wczytaj plik CSV.')),
      );
      return;
    }

    setState(() {
      _predictionResult = "Wykonuję predykcję...";
    });

    try {
      String result = await model.runInferenceOnSequence(_csvSensorData!);
      setState(() {
        _predictionResult = result;
      });
    } catch (e) {
      setState(() {
        _predictionResult = "Błąd predykcji: $e";
      });
      logger.e("Błąd predykcji na sekwencji: $e");
    }
  }

  @override
  void dispose() {
    // sensorService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_fileName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text('Wczytano: $_fileName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                if (_csvSensorData != null)
                  Text('Liczba próbek: ${_csvSensorData!.length}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickDataFromFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Wczytaj plik CSV z danymi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _csvSensorData != null ? _performInference : null,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Wykonaj Predykcję na danych z CSV'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("Wynik modelu", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Text(
                          _predictionResult ?? "Brak danych",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case 1:
        page = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_outlined, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CameraScreen(model: model)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('Nagraj Wideo', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 2:
        page = RecordingsListScreen(model: model);
        break;
      default:
        page = Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("SkiCapture"),
        centerTitle: true,
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            selectedIcon: Icon(Icons.analytics),
            icon: Icon(Icons.analytics_outlined),
            label: 'Analiza CSV',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.videocam),
            icon: Icon(Icons.videocam_outlined),
            label: 'Kamera',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.space_dashboard),
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Lista nagrań',
          ),
        ],
      ),
    );
  }
}
