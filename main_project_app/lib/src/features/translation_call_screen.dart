import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

// A model to hold a single message in the conversation
class Message {
  final String original;
  final String translated;
  final bool isFromUser;
  final String language;

  Message({
    required this.original,
    required this.translated,
    required this.isFromUser,
    this.language = '',
  });
}

class TranslationCallScreen extends StatefulWidget {
  const TranslationCallScreen({super.key});

  @override
  State<TranslationCallScreen> createState() => _TranslationCallScreenState();
}

class _TranslationCallScreenState extends State<TranslationCallScreen> {
  // --- IMPORTANT: CONFIGURE YOUR BACKEND URL ---
  // Use your computer's IP address, not localhost.
  // Example: final String _backendUrl = '192.168.1.100:8000';
  final String _backendUrl = 'YOUR_COMPUTER_IP:8000';
  // -----------------------------------------

  // State variables
  final _phoneNumberController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedLanguage = 'Japanese';
  final List<String> _languages = ['Japanese', 'English', 'Chinese', 'Spanish'];

  final List<Message> _conversation = [];
  WebSocketChannel? _channel;
  String _callStatus = 'Idle'; // Idle, Calling, Connected, Error

  @override
  void initState() {
    super.initState();
    // Pre-fill for easier testing, now in local format
    _phoneNumberController.text = '01012345678';
  }

  // --- Phone Number Formatting ---
  String _formatNumberToE164(String number) {
    // Remove non-numeric characters
    String digitsOnly = number.replaceAll(RegExp(r'\D'), '');
    // Handle Korean mobile numbers
    if (digitsOnly.startsWith('010')) {
      return '+82${digitsOnly.substring(1)}';
    }
    // If it already starts with a +, assume it's correct
    if (number.startsWith('+')) {
      return number;
    }
    // For other cases, you might add more country-specific rules.
    // We return the original digits, but this might fail if not E.164.
    return digitsOnly;
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-time Translation Call')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCallSetupUI(),
            const SizedBox(height: 16),
            _buildConversationUI(),
            _buildMessageInputUI(),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets ---
  Widget _buildCallSetupUI() {
    bool isCalling = _callStatus == 'Calling' || _callStatus == 'Connected';
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _phoneNumberController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            enabled: !isCalling,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _selectedLanguage,
          onChanged: isCalling
              ? null
              : (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                  }
                },
          items: _languages.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isCalling ? _hangUp : _makeCall,
          style: ElevatedButton.styleFrom(
            backgroundColor: isCalling ? Colors.red : Colors.green,
          ),
          child: Text(isCalling ? 'Hang Up' : 'Call'),
        ),
      ],
    );
  }

  Widget _buildConversationUI() {
    return Expanded(
      child: ListView.builder(
        itemCount: _conversation.length,
        itemBuilder: (context, index) {
          final message = _conversation[index];
          return ListTile(
            title: Text(
              message.original,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              message.translated,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
            ),
            tileColor: message.isFromUser ? Colors.blue[50] : Colors.grey[200],
            isThreeLine: true,
            leading: Icon(
              message.isFromUser ? Icons.person : Icons.phone_in_talk,
              color: Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInputUI() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Type your message...',
              border: OutlineInputBorder(),
            ),
            enabled: _callStatus == 'Connected',
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: _callStatus == 'Connected' ? _sendMessage : null,
        ),
      ],
    );
  }

  // --- Backend Logic Methods ---

  String _getWebSocketUrl(String baseUrl, String lang) {
    String wsScheme;
    String host;

    if (baseUrl.startsWith('https://')) {
      wsScheme = 'wss://';
      host = baseUrl.substring(8);
    } else if (baseUrl.startsWith('http://')) {
      wsScheme = 'ws://';
      host = baseUrl.substring(7);
    } else {
      wsScheme = 'ws://';
      host = baseUrl;
    }

    return '$wsScheme$host/ws?lang=$lang';
  }

  Future<void> _makeCall() async {
    if (_backendUrl.contains('YOUR_COMPUTER_IP')) {
      _showError('Please configure your backend URL in the source code.');
      return;
    }

    setState(() {
      _callStatus = 'Calling';
      _conversation.add(
        Message(
          original: 'Initiating call...',
          translated: '',
          isFromUser: true,
        ),
      );
    });

    final formattedNumber = _formatNumberToE164(_phoneNumberController.text);

    try {
      var url = _backendUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }

      final response = await http.post(
        Uri.parse('$url/call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'target_number': formattedNumber,
          'language': _selectedLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          _connectWebSocket();
        } else {
          _showError(body['message'] ?? 'Failed to initiate call.');
          _hangUp();
        }
      } else {
        _showError('Server error: ${response.statusCode}');
        _hangUp();
      }
    } catch (e) {
      _showError('Failed to connect to the backend: $e');
      _hangUp();
    }
  }

  void _connectWebSocket() {
    final wsUrl = _getWebSocketUrl(_backendUrl, _selectedLanguage);
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    setState(() {
      _callStatus = 'Connected';
      _conversation.removeLast(); // Remove 'Initiating call...'
      _conversation.add(
        Message(
          original: 'Connected!',
          translated: 'Waiting for audio...',
          isFromUser: false,
        ),
      );
    });

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (data['type'] == 'translation') {
          setState(() {
            _conversation.add(
              Message(
                original: data['original'],
                translated: data['translated'],
                isFromUser: false,
                language: data['language'],
              ),
            );
          });
        } else if (data['type'] == 'user_text') {
          // Update the 'Translating...' message with the actual translation
          setState(() {
            final lastMsgIndex = _conversation.lastIndexWhere(
              (m) => m.isFromUser && m.original == data['original'],
            );
            if (lastMsgIndex != -1) {
              _conversation[lastMsgIndex] = Message(
                original: data['original'],
                translated: data['translated'],
                isFromUser: true,
              );
            }
          });
        }
      },
      onDone: () {
        setState(() {
          _callStatus = 'Idle';
          _conversation.add(
            Message(original: 'Call ended.', translated: '', isFromUser: false),
          );
        });
      },
      onError: (error) {
        _showError('WebSocket error: $error');
        _hangUp();
      },
    );
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty || _channel == null) return;

    final text = _messageController.text;
    // Add to conversation for immediate feedback
    setState(() {
      _conversation.add(
        Message(original: text, translated: '(Sending...)', isFromUser: true),
      );
    });

    _channel!.sink.add(jsonEncode({'event': 'frontend_text', 'text': text}));
    _messageController.clear();
  }

  void _hangUp() {
    _channel?.sink.close();
    setState(() {
      _callStatus = 'Idle';
      _conversation.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _messageController.dispose();
    _channel?.sink.close();
    super.dispose();
  }
}
