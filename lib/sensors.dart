import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;

  List<double>? accelerometerValues;
  List<double>? gyroscopeValues;
  List<double>? magnetometerValues;

  void startListening(void Function() onUpdate) {
    _accelSub = accelerometerEvents.listen((event) {
      accelerometerValues = [event.x, event.y, event.z];
      onUpdate();
    });

    _gyroSub = gyroscopeEvents.listen((event) {
      gyroscopeValues = [event.x, event.y, event.z];
      onUpdate();
    });

    _magSub = magnetometerEvents.listen((event) {
      magnetometerValues = [event.x, event.y, event.z];
      onUpdate();
    });
  }

  void stopListening() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
  }
}
