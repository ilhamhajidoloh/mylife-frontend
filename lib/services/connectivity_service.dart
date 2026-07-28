import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;
  static final StreamController<bool> _controller = StreamController<bool>.broadcast();

  static Stream<bool> get isOnlineStream => _controller.stream;

  static bool get isOnline => _isOnline;

  static Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    _controller.add(_isOnline);

    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(result);
      if (wasOnline != _isOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  static Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  static void dispose() {
    _controller.close();
  }
}
