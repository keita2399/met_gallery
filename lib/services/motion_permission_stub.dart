import 'dart:async';

/// Native: no permission needed for accelerometer
Future<bool> requestMotionPermission() async => true;

/// Native: uses SystemChrome instead
Future<bool> tryLockOrientation() async => false;

/// Native: uses SystemChrome instead
void unlockOrientation() {}

/// Native: not used (sensors_plus handles it)
StreamController<(double, double, double)> startDeviceMotionListener() {
  return StreamController<(double, double, double)>.broadcast();
}

/// Native: not used
void stopDeviceMotionListener() {}
