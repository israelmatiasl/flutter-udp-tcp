import 'package:device_connection_wifi/services/tcp_server_service.dart';
import 'package:device_connection_wifi/widgets/client_expansion_tile.dart';
import 'package:flutter/material.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final TcpServerService _serverService = TcpServerService();

  @override
  void initState() {
    super.initState();

    _serverService.startServer(
      onClientUpdate: () => setState(() {}),
      onIpResolved: (ip) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _serverService.stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _serverService.clientMessages;

    return Scaffold(
      appBar: AppBar(
        title: Text("Servidor TCP"),
        surfaceTintColor: Colors.white,
        actions: [
          SizedBox(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: ElevatedButton(
              onPressed: () {
                _serverService.stopServer();
                Navigator.pop(context);
              },
              child: Text(
                "Disconnect",
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
              Text("Clients", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients.keys.elementAt(index);
                    final messages = clients[client];
                    return ClientExpansionTile(
                      client: client,
                      messages: messages,
                      onDisconnect: () {
                        _serverService.disconnectClient(client, () => setState(() {}));
                      }
                    );
                  },
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: _serverService.sendBroadcast,
                  child: Text(
                    _serverService.serverIp ?? "Broadcast",
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),),
                )
              )
            ]
          )
        )
      )
    );
  }
}