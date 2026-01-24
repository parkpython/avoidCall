import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:main_project_app/src/features/settings/application/settings_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KeypadScreen extends ConsumerStatefulWidget {
  const KeypadScreen({super.key});

  @override
  ConsumerState<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends ConsumerState<KeypadScreen> {
  // --- IMPORTANT: CONFIGURE YOUR BACKEND URL ---
  final String _backendUrl = dotenv.env['API_URL'] ?? '';
  // -----------------------------------------

  bool _aiMediation = true;
  String _selectedCountryCode = '+82';
  final List<Map<String, String>> _countryCodes = [
    {'code': '+82', 'name': 'South Korea'},
    {'code': '+81', 'name': 'Japan'},
    {'code': '+1', 'name': 'USA'},
    {'code': '+86', 'name': 'China'},
    {'code': '+31', 'name': 'Netherlands'},
  ];
  final TextEditingController _phoneController = TextEditingController();

  void _onNumberPressed(String number) {
    // 보안: 입력 길이 제한 (최대 20자리). 비정상적으로 긴 입력 방지.
    if (_phoneController.text.length >= 20) {
      return;
    }
    setState(() {
      _phoneController.text += number;
    });
  }

  void _onDeletePressed() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text = _phoneController.text.substring(
          0,
          _phoneController.text.length - 1,
        );
      });
    }
  }

  String _formatNumberToE164(String number) {
    // 보안: 입력값에서 숫자만 남기고 모두 제거 (화이트리스트 방식)
    String digitsOnly = number.replaceAll(RegExp(r'\D'), '');

    if (number.startsWith('+')) {
      // +로 시작하더라도 숫자만 포함되도록 강제하여 코드 삽입(Injection) 방지
      return '+$digitsOnly';
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    return '$_selectedCountryCode$digitsOnly';
  }

  Future<void> _makeCall() async {
    final language = ref.read(languageProvider);
    final greeting = ref.read(greetingProvider);
    final voice = ref.read(voiceProvider);
    final deviceId = ref.read(deviceIdProvider); // 로컬 디바이스 ID 사용
    final formattedNumber = _formatNumberToE164(_phoneController.text);

    _showFeedback('Initiating AI-mediated call in $language...');

    try {
      var url = _backendUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      final response = await http.post(
        Uri.parse('$url/call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': deviceId, // [수정] 로컬 디바이스 ID 전송
          'target_number': formattedNumber,
          'language': language,
          'greeting_text': greeting,
          'ai_mediation': _aiMediation,
          'voice_preset': voice,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          final callId = body['call_id'];
          _showFeedback('Call initiated successfully! SID: $callId');

          // Navigate to the in-call screen using push, so we can pop back to it.
          context.push(
            '/in-call-session',
            extra: {'call_id': callId, 'language': language},
          );
        } else {
          _showFeedback(
            body['message'] ?? 'Failed to initiate call.',
            isError: true,
          );
        }
      } else {
        _showFeedback('Server error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showFeedback('Failed to connect to the backend: $e', isError: true);
    }
  }

  // [테스트 모드] 백엔드 시뮬레이션 호출
  Future<void> _makeTestCall() async {
    final language = ref.read(languageProvider);
    final deviceId = ref.read(deviceIdProvider);

    _showFeedback('Starting Backend Simulation...');

    try {
      var url = _backendUrl;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }

      final response = await http.post(
        Uri.parse('$url/call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': deviceId,
          'target_number': 'TEST', // 백엔드에서 테스트 모드로 인식
          'language': language,
          'greeting_text': '',
          'ai_mediation': true,
          'voice_preset': 'alloy',
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          final callId = body['call_id'];
          // 실제 통화 세션 화면으로 이동 (call_id를 가지고 웹소켓 연결 시도)
          if (mounted) {
            context.push(
              '/in-call-session',
              extra: {'call_id': callId, 'language': language},
            );
          }
        } else {
          _showFeedback('Test failed: ${body['message']}', isError: true);
        }
      }
    } catch (e) {
      _showFeedback('Connection error: $e', isError: true);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 작은 화면 대응을 위한 최소 높이 설정 (예: 600px)
            const double minHeight = 600.0;
            final bool isSmallScreen = constraints.maxHeight < minHeight;

            return SingleChildScrollView(
              physics: isSmallScreen
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: isSmallScreen ? minHeight : constraints.maxHeight,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('AI Mediation'),
                        Switch(
                          value: _aiMediation,
                          onChanged: (value) {
                            setState(() {
                              _aiMediation = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40.0,
                        vertical: 8.0,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: const InputDecoration(
                          labelText: 'Country Code',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _countryCodes.map((country) {
                          return DropdownMenuItem<String>(
                            value: country['code'],
                            child: Text(
                              '${country['name']} (${country['code']})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCountryCode = value!);

                          // 국가 선택 시 해당 언어로 자동 변경 (UX 개선)
                          final langNotifier = ref.read(
                            languageProvider.notifier,
                          );
                          switch (value) {
                            case '+31':
                              langNotifier.setLanguage('Dutch');
                              break;
                            case '+81':
                              langNotifier.setLanguage('Japanese');
                              break;
                            case '+1':
                              langNotifier.setLanguage('English');
                              break;
                            case '+86':
                              langNotifier.setLanguage('Chinese');
                              break;
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _phoneController.text.isEmpty
                                    ? 'Enter number'
                                    : _phoneController.text,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _phoneController.text.isEmpty
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.backspace),
                            onPressed: _onDeletePressed,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildKeypad()),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FloatingActionButton(
                        onPressed:
                            _makeCall, // Changed from navigation to function call
                        child: const Icon(Icons.call),
                      ),
                    ),
                    // [테스트용] 서버 연결 없이 UI 테스트 진입 버튼
                    TextButton.icon(
                      onPressed: _makeTestCall, // 백엔드 시뮬레이션 연결
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Backend Test Call'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    // ... (keypad build logic remains the same)
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('*'),
            _buildKeypadButton('0'),
            _buildKeypadButton('#'),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String text) {
    return TextButton(
      onPressed: () => _onNumberPressed(text),
      child: Text(text, style: const TextStyle(fontSize: 28)),
    );
  }
}
