import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

class UDPConnectionTesterScreen extends StatefulWidget {
  const UDPConnectionTesterScreen({super.key});

  @override
  State<UDPConnectionTesterScreen> createState() => _UDPConnectionTesterScreenState();
}

class _UDPConnectionTesterScreenState extends State<UDPConnectionTesterScreen> {
  final TextEditingController _portController = TextEditingController(text: "41234");
  final ScrollController _logScrollController = ScrollController();
  final List<String> _logs = [];
  RawDatagramSocket? _socket;
  String _localIP = "Desconocido";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _getLocalIP();
    _startListening();
  }

  Future<void> _getLocalIP() async {
    try {
      //final NetworkInfo info = NetworkInfo();
      //final ip = await info.getWifiIP();
      //if (ip != null) {
      //  setState(() {
      //    _localIP = ip;
      //  });
      //}
      String ip = "Desconocido";
      for (var interface in await NetworkInterface.list()) {
        // Verificamos todas las interfaces (WiFi, Hotspot, Datos)
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }
        if (ip != "Desconocido") break;
      }

      setState(() {
        _localIP = ip;
      });
    } catch (e) {
      _addLog("Error al obtener IP local : $e");
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      final port = int.tryParse(_portController.text) ?? 41234;

      // Crear socket para recibir mensajes en modo broadcast
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.broadcastEnabled = true;
      _addLog("Escuchando en modo broadcast en puerto $port");

      setState(() {
        _isListening = true;
      });

      // Configurar recepción de datos
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            _addLog("Recibido de ${datagram.address.address}:${datagram.port}: $message");
          }
        }
      });
    } catch (e) {
      _addLog("Error al iniciar escucha: $e");
    }
  }

  void _stopListening() {
    _socket?.close();
    setState(() {
      _isListening = false;
    });
    _addLog("Escucha detenida");
  }

  Future<void> _sendBroadcast() async {
    try {
      final port = int.tryParse(_portController.text) ?? 41234;

      if (_localIP == "Desconocido") {
        _addLog("IP local desconocida, no se puede calcular broadcast");
        return;
      }

      // Calcular dirección de broadcast
      final parts = _localIP.split('.');
      if (parts.length != 4) {
        _addLog("Formato de IP inválido");
        return;
      }

      final broadcastIP = "${parts[0]}.${parts[1]}.${parts[2]}.255";
      final message = "Broadcast desde $_localIP - ${DateTime.now()}";
      final data = utf8.encode(message);

      // Enviar mensaje en modo broadcast
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(data, InternetAddress(broadcastIP), port);
      _addLog("Mensaje de broadcast enviado a $broadcastIP:$port");
      socket.close();
    } catch (e) {
      _addLog("Error al enviar broadcast: $e");
    }
  }

  void _addLog(String log) {
    setState(() {
      _logs.add("${DateTime.now().toString().substring(11, 19)} - $log");

      // Limitar el número de logs
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });

    // Scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socket?.close();
    _portController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Conectividad UDP'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "IP Local: $_localIP",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Puerto",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  child: Text(_isListening ? 'Detener' : 'Escuchar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendBroadcast,
                  child: const Text('Enviar Broadcast'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}