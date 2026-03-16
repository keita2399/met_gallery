import 'dart:async';
import 'dart:js_interop';

// --- DeviceMotionEvent permission ---

@JS('DeviceMotionEvent.requestPermission')
external JSPromise? _requestPermission();

@JS('DeviceMotionEvent')
external JSAny? get _deviceMotionEvent;

Future<bool> requestMotionPermission() async {
  try {
    if (_deviceMotionEvent == null) return false;

    // Check if requestPermission exists (iOS Safari only)
    JSPromise? promise;
    try {
      promise = _requestPermission();
    } catch (_) {
      // requestPermission doesn't exist (Chrome/Firefox) - no permission needed
      return true;
    }

    if (promise == null) return true;
    final result = await promise.toDart;
    return (result as JSString).toDart == 'granted';
  } catch (e) {
    return false;
  }
}

// --- Screen orientation lock ---

@JS('screen.orientation.lock')
external JSPromise _lockOrientation(JSString orientation);

@JS('screen.orientation.unlock')
external void _unlockOrientation();

Future<bool> tryLockOrientation() async {
  try {
    await _lockOrientation('portrait'.toJS).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

void unlockOrientation() {
  try {
    _unlockOrientation();
  } catch (_) {}
}

// --- Direct DeviceMotion listener ---

@JS('addEventListener')
external void _addEventListener(JSString type, JSFunction callback);

@JS('removeEventListener')
external void _removeEventListener(JSString type, JSFunction callback);

extension type _DeviceMotionEvent(JSObject _) implements JSObject {
  external JSObject? get accelerationIncludingGravity;
}

extension type _Acceleration(JSObject _) implements JSObject {
  external JSNumber? get x;
  external JSNumber? get y;
  external JSNumber? get z;
}

StreamController<(double, double, double)>? _motionController;
JSFunction? _motionCallback;

StreamController<(double, double, double)> startDeviceMotionListener() {
  _motionController = StreamController<(double, double, double)>.broadcast();

  _motionCallback = ((JSObject raw) {
    try {
      final event = _DeviceMotionEvent(raw);
      final accel = event.accelerationIncludingGravity;
      if (accel != null) {
        final a = _Acceleration(accel);
        final x = a.x?.toDartDouble ?? 0.0;
        final y = a.y?.toDartDouble ?? 0.0;
        final z = a.z?.toDartDouble ?? 0.0;
        _motionController?.add((x, y, z));
      }
    } catch (_) {}
  }).toJS;

  _addEventListener('devicemotion'.toJS, _motionCallback!);
  return _motionController!;
}

void stopDeviceMotionListener() {
  if (_motionCallback != null) {
    try {
      _removeEventListener('devicemotion'.toJS, _motionCallback!);
    } catch (_) {}
    _motionCallback = null;
  }
  _motionController?.close();
  _motionController = null;
}
