import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_connection_wifi/widgets/client_expansion_tile.dart';
import 'package:flutter/material.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  String? _serverIp;
  ServerSocket? _serverSocket;
  int portUDP = 41234;

  final Map<Socket, List<String>> _clientMessages = {};

  void startServer() async {
    _serverSocket = await ServerSocket.bind("0.0.0.0", 8080, shared: true);
    final localIp = await getLocalIp();
    setState(() {
      _serverIp = localIp;
    });

    _serverSocket!.listen((client) {
      setState(() {
        _clientMessages[client] = [];
      });
      client.listen(
        (data) {
          setState(() {
            final message = String.fromCharCodes(data);
            _clientMessages[client]?.add(message);
          });
        },
        onDone: () {
          print("Cliente desconectado : ${client.remoteAddress.address}");
          setState(() => _clientMessages.remove(client));
        },
      );
    });
  }

  void disconnectClient(Socket client) {
    client.close();
    setState(() => _clientMessages.remove(client));
  }

  void stopServer() {
    for (var client in _clientMessages.keys) {
      client.close();
    }
    _clientMessages.clear();

    _serverSocket?.close();
    Navigator.pop(context);
  }

  Future<String?> getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
    return null;
  }

  Future<void> _sendBroadcast() async {
    try {
      final parts = _serverIp!.split('.');
      if (parts.length != 4) return;

      final broadcastIP = "${parts[0]}.${parts[1]}.${parts[2]}.255";
      final message = "[${DateTime.now()}] Broadcast desde: $_serverIp";
      final data = utf8.encode(message);

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(data, InternetAddress(broadcastIP), portUDP);
      print("Mensaje de broadcast enviado a $broadcastIP:$portUDP");
      socket.close();
    } catch (e) {
      print("Error al enviar broadcast: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    startServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Servidor TCP"),
        surfaceTintColor: Colors.white,
        actions: [
          SizedBox(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: ElevatedButton(
              onPressed: stopServer,
              child: Text(
                "Desconectar",
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold
                )
              )
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Text("Clientes Conectados", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _clientMessages.length,
                  itemBuilder: (context, index) {
                    final client = _clientMessages.keys.elementAt(index);
                    final messages = _clientMessages[client];
                    return ClientExpansionTile(
                      client: client,
                      messages: messages,
                      onDisconnect: () => disconnectClient(client),
                    );
                  },
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: _sendBroadcast,
                  child: Text("$_serverIp", style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),),
                )
              )
            ]
          )
        )
      )
    );
  }
}