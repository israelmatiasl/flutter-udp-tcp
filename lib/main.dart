import 'dart:convert';
import 'dart:io';
import 'package:device_connection_wifi/client_screen.dart';
import 'package:device_connection_wifi/server_screen.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeScreen(),
    );
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String? _wifiName;
  String? _wifiBSSID;
  String? _wifiIP;
  String? _wifiGateway;
  String? _wifiSubmask;
  String? _serverIp;
  String? _statusListening;
  RawDatagramSocket? _broadcastSocket;
  bool _isListening = false;
  int portUDP = 41234;

  @override
  void initState() {
    super.initState();
    getNetworkInfo();
  }

  Future<void> getNetworkInfo() async {
    final info = NetworkInfo();

    _wifiName = await info.getWifiName() ?? "No conectado";
    _wifiBSSID = await info.getWifiBSSID() ?? "No disponible";
    _wifiIP = await info.getWifiIP() ?? "No disponible";
    _wifiGateway = await info.getWifiGatewayIP() ?? "No disponible";
    _wifiSubmask = await info.getWifiSubmask() ?? "No disponible";
    setState(() {});
  }

  void _listenForServer() async {
    if (_isListening) return;

    try {
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, portUDP);
      _broadcastSocket!.broadcastEnabled = true;
      print("Escuchando en modo broadcast en puerto $portUDP");

      setState(() {
        _isListening = true;
        _serverIp = null;
        _statusListening = "Esperando mensaje...";
      });

      _broadcastSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _broadcastSocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            print("Recibido de ${datagram.address.address}:${datagram.port}: $message");

            List<String> parts = message.split(":");
            if (parts.length > 3) {
              _serverIp = parts[3].trim();
              print("IP obtenida por message: $_serverIp");
            } else {
              _serverIp = datagram.address.address;
              print("IP obtenida por datagram: $_serverIp");
            }

            setState(() {
              //_serverIp = datagram.address.address;
              _statusListening = message;
            });

            _stopListening();
          }
        }
      });
    } catch (e) {
      print("Error al iniciar escucha: $e");
    }
  }

  void _stopListening() {
    _broadcastSocket?.close();
    setState(() {
      _isListening = false;
    });
    print("Escucha detenida");
  }

  @override
  void dispose() {
    _broadcastSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transferencia TCP")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Información de Red", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("SSID: $_wifiName"),
                    Text("BSSID: $_wifiBSSID"),
                    Text("IP: $_wifiIP"),
                    Text("Gateway: $_wifiGateway"),
                    Text("Submask: $_wifiSubmask"),
                    Text("IP Server: $_serverIp", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text("Status Listening: $_statusListening", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if(!_isListening) TextButton(
                          onPressed: _listenForServer,
                          child: Text("Escuchar"),
                        )
                        else TextButton(
                          onPressed: _stopListening,
                          child: Text("Dejar de escuchar"),
                        ),
                        TextButton(
                          onPressed: getNetworkInfo,
                          child: Text("Actualizar"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                //stopAnnounceServer();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ServerScreen()),
                );
              },
              child: Text("Iniciar como Servidor"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ClientScreen(serverIp: _serverIp),
                ));
              },
              child: Text("Conectar como Cliente"),
            ),
          ],
        ),
      ),
    );
  }
}