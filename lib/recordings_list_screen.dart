import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:logger/logger.dart';

class RecordingsListScreen extends StatefulWidget {
  final MLModel model;

  const RecordingsListScreen({super.key, required this.model});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  final Logger logger = Logger();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _runPrediction(DocumentSnapshot doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('frames')) {
        throw Exception("Brak pola 'frames' w dokumencie.");
      }

      logger.i("Raw document data: ${doc.data()}");

      List<dynamic> frames = data['frames'];
      List<List<double>> sequence = [];

      for (var frame in frames) {
         if (frame is Map && frame.containsKey('points')) {
             var points = frame['points'];
             if (points is List) {
                 List<double> features = points.map((e) => (e as num).toDouble()).toList();
                 
                 if (features.isEmpty) {
                   throw Exception("Znaleziono ramkę z pustą listą punktów.");
                 }

                 // Temporary hack: Truncate to 12 features
                 if (features.length > 12) {
                   features = features.sublist(0, 12);
                 }
                 sequence.add(features);
             }
         } else if (frame is List) {
             List<double> features = frame.map((e) => (e as num).toDouble()).toList();
             
             if (features.isEmpty) {
                throw Exception("Znaleziono ramkę z pustą listą punktów.");
             }

             sequence.add(features);
         } else {
             logger.w("Frame structure unknown/invalid: $frame");
         }
      }

      if (sequence.isEmpty) {
        throw Exception("Nie udało się sparsować żadnych ramek z danymi.");
      }

      if (mounted) {
        Navigator.of(context).pop(); 
        _showDataInspectionDialog(sequence, doc.id);
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd predykcji: ${e.toString().replaceAll('Exception: ', '')}')),
        );
        logger.e("Prediction error parsing doc ${doc.id}: $e");
      }
    }
  }

  void _showDataInspectionDialog(List<List<double>> sequence, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Dane wejściowe (${sequence.length} ramek)"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: sequence.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text("Ramka $index"),
                subtitle: Text(sequence[index].toString()),
                dense: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Anuluj"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeInference(sequence, docId);
            },
            child: const Text("Uruchom model"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeInference(List<List<double>> sequence, String docId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String result = await widget.model.runInferenceOnSequence(sequence);

      if (mounted) {
        Navigator.of(context).pop(); 
        _showResultDialog(result, docId);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd uruchamiania modelu: $e')),
        );
      }
    }
  }

  void _showResultDialog(String result, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Wynik modelu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$docId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(
              result,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('video_results')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             if (snapshot.error.toString().contains("failed-precondition")) {
                return const Center(child: Text("Błąd: Wymagany indeks Firestore lub pole timestamp nie istnieje."));
             }
             return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text('Brak nagrań w bazie.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String name = data.containsKey('name') 
                  ? data['name'] 
                  : '${doc.id.length > 23 ? doc.id.substring(0, 20) + "..." : doc.id}';
              String subtitle = doc.id;
              if (data.containsKey('timestamp')) {
                  subtitle = "ID: ${doc.id}";
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.video_file, color: Colors.blueAccent),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _runPrediction(doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
