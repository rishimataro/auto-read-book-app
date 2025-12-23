import 'dart:async';
import 'dart:convert';

import 'package:demo/data/models/book_response.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PiRepository {
  static PiRepository? _instance;
  static String? _baseUrl;  // AI Server (Laptop) URL
  static String? _piCameraIp;  // Pi Camera IP
  final aiServerPort = 5000;  // Port của AI Server (Laptop)
  final piCameraPort = 8080;  // Port của Pi Camera Server
  WebSocketChannel? _channel;
  StreamController<String> _textStreamController = StreamController.broadcast();

  PiRepository._();

  factory PiRepository() {
    _instance ??= PiRepository._();
    return _instance!;
  }

  Stream<String> get textStream => _textStreamController.stream;

  String? get baseUrl => _baseUrl;
  String? get piCameraIp => _piCameraIp;
  String? get piCameraUrl => _piCameraIp != null 
      ? 'http://$_piCameraIp:$piCameraPort' 
      : null;

  Future<String?> findAiServer() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();

    if (wifiIP == null) {
      return null;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));

    const batchSize = 20;
    String? foundIp;

    for (int start = 1; start <= 255; start += batchSize) {
      final end = (start + batchSize - 1) > 255 ? 255 : (start + batchSize - 1);
      final List<Future<String?>> batchChecks = [];

      for (int i = start; i <= end; i++) {
        batchChecks.add(_checkAiServer('$subnet.$i'));
      }

      try {
        final batchResults = await Future.wait(batchChecks);
        foundIp = batchResults.firstWhere((ip) => ip != null, orElse: () => null);
        
        if (foundIp != null) {
          _baseUrl = 'http://$foundIp:$aiServerPort';
          return foundIp;
        }
      } catch (e) {
        print('Error scanning batch $start-$end: $e');
      }
    }

    return null;
  }

  Future<String?> findPiCamera() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();

    if (wifiIP == null) {
      return null;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));

    const batchSize = 20;
    String? foundIp;

    for (int start = 1; start <= 255; start += batchSize) {
      final end = (start + batchSize - 1) > 255 ? 255 : (start + batchSize - 1);
      final List<Future<String?>> batchChecks = [];

      for (int i = start; i <= end; i++) {
        batchChecks.add(_checkPiCamera('$subnet.$i'));
      }

      try {
        final batchResults = await Future.wait(batchChecks);
        foundIp = batchResults.firstWhere((ip) => ip != null, orElse: () => null);
        
        if (foundIp != null) {
          _piCameraIp = foundIp;
          return foundIp;
        }
      } catch (e) {
        print('Error scanning batch $start-$end: $e');
      }
    }

    return null;
  }

  Future<String?> findRaspberryPi() async {
    return findAiServer();
  }

  // Future<String?> findRaspberryPi() async {
  //   final info = NetworkInfo();
  //   final wifiIP = await info.getWifiIP();
  //
  //   if (wifiIP == null) return null;
  //
  //   final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
  //   final List<Future<String?>> checks = [];
  //
  //   // Tao 255 request song song de quet dia chi IP trong mang
  //   for (int i = 1; i <= 255; i++) {
  //     checks.add(_checkIp('$subnet.$i'));
  //   }
  //
  //   final results = await Future.wait(checks);
  //   final foundIp = results.firstWhere((ip) => ip != null, orElse: () => null);
  //
  //   if (foundIp != null) {
  //     _baseUrl = 'http://$foundIp:$port';
  //   }
  //
  //   // _baseUrl = 'http://10.153.8.13:5000';
  //   // final foundIp = _baseUrl?.substring(7, _baseUrl!.indexOf(':5000'));
  //   return foundIp;
  // }

  Future<String?> _checkAiServer(String ip) async {
    try {
      final uri = Uri.parse('http://$ip:$aiServerPort/ping');
      final response = await http
          .get(uri)
          .timeout(
            const Duration(milliseconds: 1000),
            onTimeout: () {
              throw TimeoutException('Connection timeout for $ip');
            },
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && (body['device'] == 'ai_server' || body['device'] == 'smart_reader')) {
          return ip;
        }
      }
    } on TimeoutException {
      return null;
    } on http.ClientException catch (e) {
      return null;
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<String?> _checkPiCamera(String ip) async {
    try {
      final uri = Uri.parse('http://$ip:$piCameraPort/ping');
      final response = await http
          .get(uri)
          .timeout(
            const Duration(milliseconds: 1000),
            onTimeout: () {
              throw TimeoutException('Connection timeout for $ip');
            },
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['device'] == 'pi_camera') {
          return ip;
        }
      }
    } on TimeoutException {
      return null;
    } on http.ClientException catch (e) {
      return null;
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Backward compatibility
  Future<String?> _checkIp(String ip) async {
    return _checkAiServer(ip);
  }

  void connectWebSocket(String ip) {
    final wsUrl = 'ws://$ip:$aiServerPort/ws';
    _channel = IOWebSocketChannel.connect(wsUrl);
    _channel!.stream.listen(
      (message) {
        _textStreamController.add(message);
      },
      onError: (error) {
        _textStreamController.addError('Lỗi WebSocket: $error');
      },
      onDone: () {
        // Connection closed
      },
    );
  }

  Future<BookResponse> scanPage() async {
    if (_baseUrl == null) {
      throw Exception('Không tìm thấy AI Server (Laptop)');
    }

    final reponse = await http.get(Uri.parse('$_baseUrl/scan'));
    if (reponse.statusCode == 200) {
      return BookResponse.fromJson(jsonDecode(utf8.decode(reponse.bodyBytes)));
    } else {
      throw Exception('Lỗi khi quét trang: ${reponse.statusCode}');
    }
  }

  Future<void> flipPage() async {
    if (_baseUrl == null) {
      throw Exception('Không tìm thấy AI Server (Laptop)');
    }
    final response = await http.get(Uri.parse('$_baseUrl/flip'));
    if (response.statusCode != 200) {
      throw Exception('Lỗi lật trang: ${response.statusCode}');
    }
  }

  Future<void> stopReading() async {
    if (_baseUrl == null) {
      throw Exception('Không tìm thấy AI Server (Laptop)');
    }
    try {
      final response = await http.post(Uri.parse('$_baseUrl/stop_reading'));
      if (response.statusCode != 200) {
        print('Warning: stop_reading returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling stop_reading: $e');
    }
  }

  void close() {
    _channel?.sink.close();
    _textStreamController.close();
  }
}