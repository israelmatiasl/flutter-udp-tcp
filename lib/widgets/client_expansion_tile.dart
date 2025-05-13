import 'dart:io';

import 'package:flutter/material.dart';

class ClientExpansionTile extends StatefulWidget {

  final Socket client;
  final List<String>? messages;
  final Function()? onDisconnect;

  const ClientExpansionTile({
    super.key,
    required this.client,
    this.messages,
    this.onDisconnect,
  });

  @override
  State<ClientExpansionTile> createState() => _ClientExpansionTileState();
}

class _ClientExpansionTileState extends State<ClientExpansionTile> {

  bool _customTileExpanded = false;
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      try {
        widget.client.write(message);
        setState(() {
          _messageController.clear();
        });
      } catch (e) {
        print("Error al enviar el mensaje: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final messages = widget.messages;

    return ExpansionTile(
      leading: Icon(Icons.phone_android),
      title: Text("IP: ${client.remoteAddress.address}"),
      subtitle: Text("Mensajes recibidos: ${messages?.length ?? 0}"),
      trailing: Icon(_customTileExpanded ? Icons.keyboard_arrow_up:  Icons.keyboard_arrow_down),
      onExpansionChanged: (bool expanded) {
        setState(() { _customTileExpanded = expanded; });
      },
      children: [
        TextButton(onPressed: widget.onDisconnect, child: Text("Desconectar a este cliente", style: TextStyle(color: Colors.red))),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _messageController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Escribe tu mensaje...",
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ),
          ),
        ),
        const Divider(),
        ...messages!.map((msg) => ListTile(title: Text(msg))).toList()
      ],
    );
  }
}
