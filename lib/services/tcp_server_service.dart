import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TcpServerService {
  ServerSocket? _serverSocket;
  final Map<Socket, List<String>> _clientMessages = {};
  final int tcpPort = 8080;
  final int udpPort = 41234;

  String? serverIp;

  Map<Socket, List<String>> get clientMessages => _clientMessages;

  Future<void> startServer({
    required Function() onClientUpdate,
    required Function(String) onIpResolved,
  }) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort, shared: true);
    serverIp = await _getLocalIp();
    onIpResolved(serverIp!);

    _serverSocket!.listen((client) {
      _clientMessages[client] = [];
      onClientUpdate();

      client.listen((data) {
        try {
          final message = String.fromCharCodes(data);
          if (_clientMessages.containsKey(client)) {
            _clientMessages[client]!.add(message);
            onClientUpdate();
          }
        } catch (e) {
          print("Error during data from client: $e");
        }
      }, onDone: () {
        print("Client was disconnected: ${client.remoteAddress.address}");
        _clientMessages.remove(client);
        onClientUpdate();
      }, onError: (error) {
        print("Error en cliente ${client.remoteAddress.address}: $error");
        _clientMessages.remove(client);
        client.close();
        onClientUpdate();
      });
    });
  }

  void disconnectClient(Socket client, Function() onClientUpdate) {
    client.close();
    _clientMessages.remove(client);
    onClientUpdate();
  }

  void stopServer() {
    for (var client in _clientMessages.keys) {
      client.close();
    }
    _clientMessages.clear();
    _serverSocket?.close();
  }

  Future<void> sendBroadcast() async {
    if (serverIp == null) return;

    try {
      final parts = serverIp!.split('.');
      if (parts.length != 4) return;

      final broadcastIP = "${parts[0]}.${parts[1]}.${parts[2]}.255";
      final message = "[${DateTime.now()}] Broadcast from: $serverIp";
      final data = utf8.encode(message);

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(data, InternetAddress(broadcastIP), udpPort);
      socket.close();
    } catch (e) {
      print("Error on broadcast: $e");
    }
  }

  Future<String?> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          return address.address;
        }
      }
    }
    return null;
  }
}