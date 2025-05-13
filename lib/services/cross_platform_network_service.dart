
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:udp/udp.dart';

class CrossPlatformNetworkService {
  static const int PORT = 41234;
  static const int DISCOVERY_PORT = 41235;

  // Para generar un ID único para el dispositivo
  final String deviceId = DateTime.now().millisecondsSinceEpoch.toString();

  UDP? _sender;
  UDP? _receiver;
  Timer? _discoveryTimer;
  // Lista para almacenar las direcciones IP de los dispositivos descubiertos como strings
  final List<String> _discoveredDevices = [];
  final NetworkInfo _networkInfo = NetworkInfo();

  final StreamController<Map<String, dynamic>> _dataStreamController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// Inicializa el servicio de red
  Future<void> init() async {
    try {
      // Configurar el emisor (para enviar mensajes)
      _sender = await UDP.bind(Endpoint.any(port: const Port(0)));

      // Configurar el receptor (para recibir mensajes)
      _receiver = await UDP.bind(Endpoint.any(port: const Port(PORT)));

      // Escuchar mensajes entrantes
      _receiver!.asStream().listen((datagram) {
        if (datagram != null && datagram.data != null) {
          try {
            final String message = String.fromCharCodes(datagram.data!);
            final Map<String, dynamic> data = jsonDecode(message);

            // Solo procesar mensajes que no sean del propio dispositivo
            if (data['deviceId'] != deviceId) {
              _dataStreamController.add(data);
            }
          } catch (e) {
            print('Error al procesar mensaje: $e');
          }
        }
      });

      // Iniciar el servicio de descubrimiento
      _startDiscoveryService();

      print('Servicio de red inicializado. Escuchando en el puerto $PORT');
    } catch (e) {
      print('Error al inicializar el servicio de red: $e');
    }
  }

  /// Inicia el servicio de descubrimiento de dispositivos
  void _startDiscoveryService() async {
    try {
      // Configurar receptor para descubrimiento
      final discoveryReceiver = await UDP.bind(Endpoint.any(port: const Port(DISCOVERY_PORT)));

      // Escuchar solicitudes de descubrimiento
      discoveryReceiver.asStream().listen((datagram) {
        if (datagram != null && datagram.data != null) {
          try {
            final String message = String.fromCharCodes(datagram.data!);
            final Map<String, dynamic> data = jsonDecode(message);

            if (data['type'] == 'discovery' && data['deviceId'] != deviceId) {
              // Responder al dispositivo que nos descubrió
              _sendDirectMessage({
                'type': 'discovery_response',
                'deviceId': deviceId,
                'port': PORT,
              }, datagram.address.address, data['port']);

              // Agregar a la lista de dispositivos descubiertos
              final deviceAddress = datagram.address.address;
              if (!_discoveredDevices.contains(deviceAddress)) {
                _discoveredDevices.add(deviceAddress);
              }
            }
          } catch (e) {
            print('Error en el servicio de descubrimiento: $e');
          }
        }
      });

      // Enviar periódicamente mensajes de descubrimiento
      _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _broadcastDiscovery();
      });

      // Enviar un mensaje de descubrimiento inicial
      _broadcastDiscovery();
    } catch (e) {
      print('Error al iniciar el servicio de descubrimiento: $e');
    }
  }

  /// Envía un mensaje de descubrimiento por broadcast
  Future<void> _broadcastDiscovery() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) return;

      // Obtener la dirección de broadcast
      final parts = wifiIP.split('.');
      if (parts.length != 4) return;

      final broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';

      await _sendDirectMessage({
        'type': 'discovery',
        'deviceId': deviceId,
        'port': DISCOVERY_PORT,
      }, broadcastAddress, DISCOVERY_PORT);

    } catch (e) {
      print('Error al enviar descubrimiento: $e');
    }
  }

  /// Envía un mensaje directo a una dirección IP específica
  Future<void> _sendDirectMessage(Map<String, dynamic> data, String address, int port) async {
    if (_sender == null) return;

    try {
      final String jsonData = jsonEncode(data);
      final List<int> dataToSend = utf8.encode(jsonData);

      await _sender!.send(
        dataToSend,
        Endpoint.unicast(
          InternetAddress(address),
          port: Port(port),
        ),
      );
    } catch (e) {
      print('Error al enviar mensaje directo a $address:$port - $e');
    }
  }

  /// Envía un mensaje a todos los dispositivos descubiertos en la red
  Future<void> broadcastMessage(Map<String, dynamic> message) async {
    if (_sender == null) {
      throw Exception('Sender no inicializado. Llama a init() primero.');
    }

    // Añadir ID de dispositivo al mensaje
    final Map<String, dynamic> fullMessage = {
      ...message,
      'deviceId': deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final String jsonData = jsonEncode(fullMessage);
    final List<int> dataToSend = utf8.encode(jsonData);

    try {
      // Obtener la dirección IP de la WiFi
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) return;

      // Obtener la dirección de broadcast
      final parts = wifiIP.split('.');
      if (parts.length != 4) return;

      final broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';

      // Enviar a la dirección de broadcast
      await _sender!.send(
        dataToSend,
        Endpoint.broadcast(
          port: const Port(PORT),
        ),
      );

      // También intentar enviar directamente al broadcast de la subred
      await _sender!.send(
        dataToSend,
        Endpoint.unicast(
          InternetAddress(broadcastAddress),
          port: const Port(PORT),
        ),
      );

      // Enviar a todos los dispositivos descubiertos individualmente
      for (final address in _discoveredDevices) {
        try {
          await _sendDirectMessage(fullMessage, address, PORT);
        } catch (e) {
          print('Error al enviar a dispositivo descubierto $address: $e');
        }
      }

      print('Mensaje enviado a la red: $jsonData');
    } catch (e) {
      print('Error al enviar mensaje: $e');
    }
  }

  /// Libera recursos
  void dispose() {
    _sender?.close();
    _receiver?.close();
    _discoveryTimer?.cancel();
    _dataStreamController.close();
  }
}