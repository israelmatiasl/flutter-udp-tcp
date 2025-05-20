import 'package:device_connection_wifi/services/tcp_client_service.dart';
import 'package:flutter/material.dart';

class ClientScreen extends StatefulWidget {
  final String? serverIp;
  const ClientScreen({super.key, this.serverIp});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {

  final TcpClientService _clientService = TcpClientService();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _status = "Waiting connection...";
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.serverIp ?? "";
    if(widget.serverIp != null) {
      _connectClient();
    }
  }

  void _connectClient() async {
    final ip = _ipController.text;

    _clientService.connect(
      serverIp: ip,
      onStatusChange: (status) {
        setState(() => _status = status);
      },
      onMessageReceived: (message) {
        setState(() => _messages = List.from(_clientService.receivedMessages));
      },
      onAlertReceived: () {
        _showDangerAlert();
      },
      onDisconnected: () {
        setState(() => _status = "Disconnected from server");
      },
    );
  }

  void _sendMessage() {
    final msg = _messageController.text;
    if (msg.isNotEmpty) {
      _clientService.send(msg, onMessageReceived: (message) {
        setState(() => _messages = List.from(_clientService.receivedMessages));
      });
      _messageController.clear();
    }
  }

  void _disconnectClient() {
    _clientService.disconnect();
    setState(() {
      _status = "Disconnected from server";
      _messages = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _clientService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text("Client TCP"),
        surfaceTintColor: Colors.white,
        actions: [
          SizedBox(),
          if (isConnected)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: ElevatedButton(
              onPressed: _disconnectClient,
              child: Text("Disconnect", style: TextStyle(fontSize: 12.0, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          )
          else SizedBox()
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!isConnected) ...[
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "Type Server IP",
                  border: OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: _connectClient,
                    child: Padding(padding: EdgeInsets.symmetric(horizontal: 10.0), child: Text("Connect")),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(_status, style: TextStyle(color: Colors.grey, fontSize: 12.0)),
                ],
              )
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Write your message...",
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(top: 10.0),
                  children: _messages.map(
                    (msg) => ListTile(
                      title: Text(msg)
                    )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDangerAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.amberAccent,
          title: Text(
            "⚠️ ALERTA DE SEGURIDAD ⚠️",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("Se ha recibido una señal crítica desde el servidor."),
              SizedBox(height: 8),
              Text("El sistema ha detectado una condición de riesgo."),
              SizedBox(height: 12),
              Text("Acción remota en curso."),
            ],
          ),
        );
      },
    );

    Future.delayed(Duration(seconds: 6), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // cierra la alerta automáticamente
      }
    });
  }
}