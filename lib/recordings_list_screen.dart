import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'package:logger/logger.dart';
import 'video_preview_screen.dart';

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

      List<List<double>> sequence = MLModel.parseFrames(data);

      if (sequence.isEmpty) {
        throw Exception("Nie udało się sparsować żadnych ramek z danymi.");
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPreviewScreen(
              docId: doc.id,
              sequence: sequence,
              model: widget.model,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd przygotowania danych: ${e.toString().replaceAll('Exception: ', '')}')),
        );
        logger.e("Data parsing error for doc ${doc.id}: $e");
      }
    }
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
              String subtitle = data.containsKey('classification')
                  ? "Klasa: ${data['classification']}"
                  : "Klasyfikacja: brak";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.video_file, color: Colors.blueAccent),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _runPrediction(doc),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String value) {
                          if (value == 'rename') {
                            _renameRecording(doc, name);
                          } else if (value == 'delete') {
                            _deleteRecording(doc);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Zmień nazwę'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Usuń', style: TextStyle(color: Colors.red)),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  onTap: () => _runPrediction(doc),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _renameRecording(DocumentSnapshot doc, String currentName) async {
    TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zmień nazwę'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Nowa nazwa"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('video_results')
                      .doc(doc.id)
                      .update({'name': controller.text});
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRecording(DocumentSnapshot doc) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Usuń nagranie'),
          content: const Text('Czy na pewno chcesz usunąć to nagranie? Tego nie można cofnąć.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('video_results')
                    .doc(doc.id)
                    .delete();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Usuń', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
