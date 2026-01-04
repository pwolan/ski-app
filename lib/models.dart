import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:logger/logger.dart';

final classes = ['carving', 'quick', 'skidded', 'snowplow'];

class MLModel {
  OrtSession? _session;
  final logger = Logger();

  Future<void> loadModel() async {
    try {
      final ort = OnnxRuntime();
      final session = await ort.createSessionFromAsset('assets/model.onnx');
      _session = session;
      logger.i("Model załadowany pomyślnie.");
    } catch (e) {
      logger.e("Błąd podczas ładowania modelu: $e");
    }
  }

  Future<String> runInferenceOnSequence(List<List<double>> sensorData) async {
    if (_session == null) {
      throw Exception("Model nie został załadowany.");
    }

    final int sequenceLength = sensorData.length;
    final int numberOfFeatures =
        sensorData.isNotEmpty ? sensorData[0].length : 0;

    final List<double> flattenedData =
        sensorData.expand((list) => list).toList();

    final inputs = {
      'input_data': await OrtValue.fromList(flattenedData, [
        1,
        sequenceLength,
        numberOfFeatures,
      ]),
    };


    logger.i(
      "Running inference with input shape: [1, $sequenceLength, $numberOfFeatures]",
    );

    final outputs = await _session!.run(inputs);

    logger.i("Output keys: ${outputs.keys}");

    final outputValue = outputs['out']!;

    final List outputData = await outputValue.asList();

    for (var tensor in inputs.values) {
      tensor.dispose();
    }
    for (var tensor in outputs.values) {
      tensor.dispose();
    }
    if (outputData.isEmpty) {
      return "Błąd, brak predykcji";
    }
    List<double> probabilities = (outputData[0] as List).cast<double>();
    double maxValue = probabilities.reduce(
      (double curr, double next) => curr > next ? curr : next,
    );
    int maxIndex = probabilities.indexOf(maxValue);

    return classes[maxIndex];
  }

  static List<List<double>> parseFrames(Map<String, dynamic> data) {
    if (!data.containsKey('frames')) {
      throw Exception("Brak pola 'frames' w dokumencie.");
    }

    List<dynamic> frames = data['frames'];
    List<List<double>> sequence = [];

    for (var frame in frames) {
      if (frame is Map && frame.containsKey('points')) {
        var points = frame['points'];
        if (points is List) {
          List<double> features =
              points.map((e) => (e as num).toDouble()).toList();

          if (features.isEmpty) {
            throw Exception("Znaleziono ramkę z pustą listą punktów.");
          }

          sequence.add(features);
        }
      } else if (frame is List) {
        List<double> features =
            frame.map((e) => (e as num).toDouble()).toList();

        if (features.isEmpty) {
          throw Exception("Znaleziono ramkę z pustą listą punktów.");
        }

        sequence.add(features);
      } else {
        // Warning: using print/logger here strictly requires an instance or static logger
        // For simplicity, we just skip invalid frames or throw.
        // throw Exception("Frame structure unknown/invalid: $frame");
      }
    }

    if (sequence.isEmpty) {
      throw Exception("Nie udało się sparsować żadnych ramek z danymi.");
    }

    return sequence;
  }
}
