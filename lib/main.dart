import 'dart:convert';
import 'dart:io';
import 'package:device_connection_wifi/client_screen.dart';
import 'package:device_connection_wifi/server_screen.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_connection_wifi/services/network_service.dart';

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

  final NetworkService _networkService = NetworkService();

  String? _wifiName;
  String? _wifiBSSID;
  String? _wifiIP;
  String? _wifiGateway;
  String? _wifiSubmask;
  String? _serverIp;
  String? _statusListening;
  bool _isListening = false;
  int portUDP = 41234;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _getNetworkInfo();
    if (_isListening) _stopListening();
    _listenForServer();
  }

  Future<void> _getNetworkInfo() async {
    final info = await _networkService.getNetworkInfo();
    setState(() {
      _wifiName = info["wifiName"];
      _wifiBSSID = info["wifiBSSID"];
      _wifiIP = info["wifiIP"];
      _wifiGateway = info["wifiGateway"];
      _wifiSubmask = info["wifiSubmask"];
    });
  }

  void _listenForServer() async {
    if (_isListening) return;

    print("Start listening");
    await _networkService.listenForServer(
      portUDP: portUDP,
      onListeningStarted: () {
        setState(() {
          _isListening = true;
          _serverIp = null;
          _statusListening = "Waiting message...";
        });
      },
      onMessageReceived: (message, ip) {
        print("Message: $message, IP: $ip");
        setState(() => _serverIp = ip);
      },
      onStatusChanged: (status) { },
      onListeningStopped: () {
        print("Stop listening");
        setState(() {
          _isListening = false;
          _statusListening = "Listening stopped";
        });
      },
    );
  }

  void _stopListening() {
    print("Stop listening");
    _networkService.dispose();
    setState(() {
      _isListening = false;
      _statusListening = "Listening stopped";
    });
  }

  @override
  void dispose() {
    _networkService.dispose();
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
                    _InfoText(title: "SSID", value: _wifiName),
                    _InfoText(title: "BSSID", value: _wifiBSSID),
                    _InfoText(title: "IP", value: _wifiIP),
                    _InfoText(title: "Gateway", value: _wifiGateway),
                    _InfoText(title: "SubMask", value: _wifiSubmask),
                    _InfoText(title: "IP Sever", value: _serverIp, isBold: _serverIp != null),
                    _InfoText(title: "Status", value: _statusListening),
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
                          onPressed: _loadData,
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
                _stopListening();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ServerScreen()),
                );
              },
              child: Text("Iniciar como Servidor"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed:
              _serverIp == null ? null :
                  () async {
                _stopListening();
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

class _InfoText extends StatelessWidget {

  final String? title;
  final String? value;
  final bool isBold;

  const _InfoText({super.key, this.title, this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(
          style: TextStyle(color: Colors.black, fontSize: 12.0),
          children: [
            TextSpan(text: "$title: "),
            TextSpan(
              text: value ?? "No data",
              style: TextStyle(
                backgroundColor: isBold ? Colors.amberAccent : null,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal
              )
            )
          ]
        )
      ),
    );
  }
}
