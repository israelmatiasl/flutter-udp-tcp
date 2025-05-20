import 'dart:io';

class TcpClientService {
  Socket? _clientSocket;
  final int _tcpPort = 8080;
  final List<String> _receivedMessages = [];

  List<String> get receivedMessages => List.unmodifiable(_receivedMessages);
  bool get isConnected => _clientSocket != null;

  Future<void> connect({
    required String serverIp,
    required void Function(String) onStatusChange,
    required void Function(String) onMessageReceived,
    required void Function() onAlertReceived,
    required void Function() onDisconnected,
  }) async {
    try {
      _clientSocket = await Socket.connect(serverIp, _tcpPort);
      onStatusChange("Connected to server");

      _clientSocket!.listen(
        (data) {
          final message = String.fromCharCodes(data);

          if (message.trim().toUpperCase() == "ALERT01") {
            onAlertReceived();
          } else {
            _receivedMessages.add("S: $message");
            onMessageReceived(message);
          }
        },
        onDone: () {
          disconnect();
          onDisconnected();
        },
        onError: (error) {
          onStatusChange("Error in connection: $error");
        },
      );
    } catch (e) {
      onStatusChange("Error in connection: $e");
    }
  }

  void send(String message, { required void Function(String) onMessageReceived }) {
    if (_clientSocket != null && message.isNotEmpty) {
      _clientSocket!.write(message);
      _receivedMessages.add("C: $message");
      onMessageReceived(message);
    }
  }

  void disconnect() {
    if (_clientSocket != null) {
      _clientSocket!.write("Client disconnected");
      _clientSocket!.close();
      _clientSocket = null;
      _receivedMessages.clear();
    }
  }
}