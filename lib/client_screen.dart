import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class ClientScreen extends StatefulWidget {
  final String? serverIp;
  const ClientScreen({super.key, this.serverIp});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {

  String? _serverIp;
  Socket? _clientSocket;
  String _status = "Esperando...";
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final List<String> _receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.serverIp ?? "";
    //connectClient();
  }

  void connectClient() async {
    _serverIp = _ipController.text;
    try {
      _clientSocket = await Socket.connect(_serverIp, 8080);
      setState(() => _status = "Conectado al servidor");

      _clientSocket?.listen((data) {
        setState(() => _receivedMessages.add(String.fromCharCodes(data)));
      }, onDone: () {
        disconnectClient();
      }, onError: (error) {
        setState(() => _status = "Error de conexión: $error");
      });
      print(_status);
    } catch (e) {
      setState(() => _status = "Error de conexión: $e");
      print(_status);
    }
  }

  void sendMessage() {
    if (_clientSocket != null && _messageController.text.isNotEmpty) {
      _clientSocket!.write(_messageController.text);
      _messageController.clear();
    }
  }

  void disconnectClient() {
    if (_clientSocket != null) {
      _clientSocket!.write("Cliente desconectado");
      _clientSocket!.close();
      setState(() {
        _clientSocket = null;
        _status = "Desconectado del servidor";
        _receivedMessages.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Client TCP"),
        surfaceTintColor: Colors.white,
        actions: [
          SizedBox(),
          if (_clientSocket != null) Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: ElevatedButton(
                onPressed: disconnectClient,
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
          else SizedBox()
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_clientSocket == null) ...[
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Ingresar IP del Servidor",
                  border: OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: connectClient,
                    child: Padding(padding: EdgeInsets.symmetric(horizontal: 10.0), child: Text("Conectar")),
                  ),
                ),
              ),
              Text(_status, style: TextStyle(color: Colors.grey, fontSize: 10.0)),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Escribe tu mensaje...",
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: sendMessage,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: _receivedMessages.map((msg) => ListTile(title: Text(msg))).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}