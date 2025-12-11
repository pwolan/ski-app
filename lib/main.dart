import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert'; // Do dekodowania CSV
import 'models.dart';
import 'package:logger/logger.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Wygenerowane przez flutterfire configure

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
      title: 'Ski Technique Analyzer',
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

  Future<void> _addTestDocument() async {
    try {
      await FirebaseFirestore.instance.collection('test_collection').add({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Hello from Flutter!',
        'device': Platform.operatingSystem,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodano dokument do test_collection')),
      );
    } catch (e) {
      logger.e("Błąd Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu do Firestore: $e')),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text("Analiza techniki jazdy (CSV)")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_fileName != null)
                Text('Wczytano: $_fileName', style: const TextStyle(fontSize: 16)),
              if (_csvSensorData != null)
                Text('Liczba próbek: ${_csvSensorData!.length}', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickDataFromFile,
                child: const Text('Wczytaj plik CSV z danymi'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _csvSensorData != null ? _performInference : null,
                child: const Text('Wykonaj Predykcję na danych z CSV'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addTestDocument,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Dodaj testowy dokument do Firestore'),
              ),
              const SizedBox(height: 30),
              Text(
                'Wynik modelu: ${_predictionResult ?? "Brak predykcji"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
