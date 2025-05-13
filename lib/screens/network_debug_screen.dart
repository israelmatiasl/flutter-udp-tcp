import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:udp/udp.dart';

class NetworkDebugScreen extends StatefulWidget {
  const NetworkDebugScreen({super.key});

  @override
  State<NetworkDebugScreen> createState() => _NetworkDebugScreenState();
}

class _NetworkDebugScreenState extends State<NetworkDebugScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();
  String _debugInfo = "Iniciando diagnóstico...";
  List<String> _logMessages = [];
  Timer? _pingTimer;
  bool _isSendingPings = false;
  final int _debugPort = 41236;
  UDP? _debugReceiver;
  UDP? _debugSender;

  @override
  void initState() {
    super.initState();
    _getNetworkInfo();
    _initDebugReceiver();
  }

  Future<void> _initDebugReceiver() async {
    try {
      _debugReceiver = await UDP.bind(Endpoint.any(port: Port(_debugPort)));
      _debugReceiver!.asStream().listen((datagram) {
        if (datagram != null && datagram.data != null) {
          final message = String.fromCharCodes(datagram.data!);
          _addLogMessage("Recibido desde ${datagram.address.address}: $message");
        }
      });
      _addLogMessage("Receptor de diagnóstico iniciado en puerto $_debugPort");
    } catch (e) {
      _addLogMessage("Error al iniciar receptor de diagnóstico: $e");
    }
  }

  Future<void> _getNetworkInfo() async {
    try {
      StringBuffer info = StringBuffer();

      info.writeln("INFORMACIÓN DE RED");
      info.writeln("-----------------");

      final wifiName = await _networkInfo.getWifiName() ?? "Desconocido";
      final wifiIP = await _networkInfo.getWifiIP() ?? "Desconocido";
      final wifiBSSID = await _networkInfo.getWifiBSSID() ?? "Desconocido";

      info.writeln("WiFi: $wifiName");
      info.writeln("IP: $wifiIP");
      info.writeln("BSSID: $wifiBSSID");

      // Prueba de broadcast
      info.writeln("\nPRUEBA DE CONECTIVIDAD");
      info.writeln("-----------------");

      if (wifiIP != "Desconocido") {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          final broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          info.writeln("Dirección de broadcast: $broadcastAddress");
        }
      }

      setState(() {
        _debugInfo = info.toString();
      });
    } catch (e) {
      setState(() {
        _debugInfo = "Error al obtener información de red: $e";
      });
    }
  }

  void _togglePingSender() async {
    if (_isSendingPings) {
      // Detener los pings y cerrar el socket de envío
      _pingTimer?.cancel();
      _debugSender?.close();
      _debugSender = null;
      _addLogMessage("Pings detenidos y socket cerrado");
    } else {
      try {
        // Verificamos si el socket ya está inicializado
        if (_debugSender == null) {
          _debugSender = await UDP.bind(Endpoint.any(port: const Port(0)));
          _addLogMessage("Emisor de pings inicializado");
        }

        // Iniciar el envío de pings
        _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
          try {
            // Verificar que el socket siga activo
            if (_debugSender == null) {
              _addLogMessage("Socket de envío no inicializado. Reiniciando...");
              _debugSender = await UDP.bind(Endpoint.any(port: const Port(0)));
            }

            final wifiIP = await _networkInfo.getWifiIP();
            if (wifiIP != null) {
              final parts = wifiIP.split('.');
              if (parts.length == 4) {
                final broadcastAddress = '${parts[0]}.${parts[1]}.${parts[2]}.255';
                final message = "PING-${DateTime.now().millisecondsSinceEpoch}";

                // Verificamos nuevamente que el socket esté inicializado antes de enviar
                if (_debugSender != null) {
                  //await _debugSender!.send(
                  //  message.codeUnits,
                  //  Endpoint.broadcast(port: Port(_debugPort)),
                  //);

                  // También probamos con la dirección de broadcast calculada
                  await _debugSender!.send(
                    message.codeUnits,
                    Endpoint.unicast(InternetAddress(broadcastAddress), port: Port(_debugPort)),
                  );

                  _addLogMessage("Ping enviado a broadcast y a $broadcastAddress:$_debugPort");
                } else {
                  _addLogMessage("El socket de envío no está inicializado.");
                }
              }
            }
          } catch (e) {
            _addLogMessage("Error enviando ping: $e");
          }
        });
      } catch (e) {
        _addLogMessage("Error inicializando el emisor de pings: $e");
      }
    }

    setState(() {
      _isSendingPings = !_isSendingPings;
    });
  }

  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add("${DateTime.now().toString().substring(11, 19)}: $message");
      if (_logMessages.length > 100) {
        _logMessages.removeAt(0);
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _logMessages.clear();
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _debugReceiver?.close();
    _debugSender?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Red'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getNetworkInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blue.shade100,
            width: double.infinity,
            child: Text(
              _debugInfo,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _togglePingSender,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSendingPings ? Colors.red : Colors.green,
              ),
              child: Text(_isSendingPings ? 'Detener Pings' : 'Iniciar Pings'),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                itemCount: _logMessages.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logMessages[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
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