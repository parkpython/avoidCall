import 'dart:async'; // <--- 이 줄을 추가하세요
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Using a shared Message model would be ideal, but for simplicity,
// we define it here. In a real app, this would be in a shared location.
class Message {
  final String original;
  final String translated;
  final bool isFromUser;

  Message({
    required this.original,
    required this.translated,
    required this.isFromUser,
  });
}

class InCallScreen extends StatefulWidget {
  final String callId;
  final String language;

  const InCallScreen({super.key, required this.callId, required this.language});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  // --- IMPORTANT: CONFIGURE YOUR BACKEND URL ---
  final String _backendUrl = dotenv.env['API_URL'] ?? '';
  // -----------------------------------------

  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  WebSocketChannel? _channel;
  bool _isCallConnected = false; // 통화 연결 상태 확인용 변수

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  // --- WebSocket Logic ---
  String _getWebSocketUrl(String baseUrl, String callId) {
    String wsScheme;
    String host;
    if (baseUrl.startsWith('https://')) {
      wsScheme = 'wss://';
      host = baseUrl.substring(8);
    } else if (baseUrl.startsWith('http://')) {
      wsScheme = 'ws://';
      host = baseUrl.substring(7);
    } else {
      wsScheme = 'wss://';
      host = baseUrl;
    }
    return '$wsScheme$host/ws/app/$callId';
  }

  void _connectWebSocket() {
    final wsUrl = _getWebSocketUrl(_backendUrl, widget.callId);
    debugPrint('Connecting to WebSocket: $wsUrl');
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (message) {
        debugPrint('<<< WebSocket Received: $message');
        if (mounted) {
          final data = jsonDecode(message);

          // 연결 이벤트나 메시지가 오면 통화 연결로 간주하고 타이머 시작
          if (data['type'] == 'call_connected' ||
              data['type'] == 'translation') {
            if (!_isCallConnected) {
              _isCallConnected = true;
            }
          }

          setState(() {
            if (data['type'] == 'translation') {
              _messages.add(
                Message(
                  original: data['original'],
                  translated: data['translated'],
                  isFromUser: false,
                ),
              );
            } else if (data['type'] == 'user_text') {
              final lastMsgIndex = _messages.lastIndexWhere(
                (m) => m.isFromUser && m.original == data['original'],
              );
              if (lastMsgIndex != -1) {
                _messages[lastMsgIndex] = Message(
                  original: data['original'],
                  translated: data['translated'],
                  isFromUser: true,
                );
              }
            } else if (data['type'] == 'call_connected') {
              _isCallConnected = true;
            } else if (data['type'] == 'call_ended') {
              // 백엔드에서 명시적으로 종료 이벤트를 보낸 경우
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call Ended by remote party.'),
                  duration: Duration(seconds: 3),
                ),
              );
              GoRouter.of(context).pop();
            }
          });
        }
      },
      onDone: () {
        debugPrint('!!! WebSocket connection closed (onDone).');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call Ended: WebSocket disconnected.'),
              duration: Duration(seconds: 3),
            ),
          );
          GoRouter.of(context).pop();
        }
      },
      onError: (error) {
        debugPrint('### WebSocket Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call Error: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          GoRouter.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty || _channel == null) return;
    _textController.clear();

    setState(() {
      _messages.add(
        Message(original: text, translated: '(Sending...)', isFromUser: true),
      );
    });

    final message = jsonEncode({'event': 'frontend_text', 'text': text});
    debugPrint('>>> WebSocket Sending: $message');
    _channel!.sink.add(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCallConnected ? 'In Call (${widget.language})' : 'Dialing...',
        ),
      ),
      body: !_isCallConnected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Ringing...',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Waiting for answer...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ListTile(
                        title: Text(
                          message.original,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          message.translated,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        tileColor: message.isFromUser
                            ? Colors.blue[50]
                            : Colors.grey[200],
                        isThreeLine: true,
                        leading: Icon(
                          message.isFromUser
                              ? Icons.person
                              : Icons.phone_in_talk,
                          color: Theme.of(context).primaryColor,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1.0),
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: _buildTextComposer(),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Always allow user to navigate back.
                      GoRouter.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('End Call'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
