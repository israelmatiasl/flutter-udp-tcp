import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkService {
  final NetworkInfo _info = NetworkInfo();
  RawDatagramSocket? _broadcastSocket;

  Future<Map<String, String?>> getNetworkInfo() async {
    return {
      "wifiName": await _info.getWifiName() ?? "No conectado",
      "wifiBSSID": await _info.getWifiBSSID() ?? "No disponible",
      "wifiIP": await _info.getWifiIP() ?? "No disponible",
      "wifiGateway": await _info.getWifiGatewayIP() ?? "No disponible",
      "wifiSubmask": await _info.getWifiSubmask() ?? "No disponible",
    };
  }

  void dispose() {
    _broadcastSocket?.close();
  }

  Future<void> listenForServer({
    required int portUDP,
    required Function(String message, String ip) onMessageReceived,
    required Function(String status) onStatusChanged,
    required Function() onListeningStarted,
    required Function() onListeningStopped,
  }) async {
    _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, portUDP);
    _broadcastSocket!.broadcastEnabled = true;

    onListeningStarted();

    _broadcastSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _broadcastSocket!.receive();
        if (datagram != null) {
          final message = utf8.decode(datagram.data);
          final ip = message.split(":").length > 3
              ? message.split(":")[3].trim()
              : datagram.address.address;

          onMessageReceived(message, ip);
          onStatusChanged(message);

          _broadcastSocket?.close();
          onListeningStopped();
        }
      }
    });
  }
}