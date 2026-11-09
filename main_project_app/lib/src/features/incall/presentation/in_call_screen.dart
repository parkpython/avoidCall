import 'dart:async'; // <--- 이 줄을 추가하세요
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:main_project_app/src/core/network/backend_client.dart';
import 'package:main_project_app/src/features/settings/application/settings_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Using a shared Message model would be ideal, but for simplicity,
// we define it here. In a real app, this would be in a shared location.
class Message {
  final String original;
  final String translated;
  final String? refined; // [추가] AI 보정 텍스트
  final String? pendingId;
  final bool isFromUser;

  Message({
    required this.original,
    required this.translated,
    this.refined,
    this.pendingId,
    required this.isFromUser,
  });
}

class InCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String language;

  const InCallScreen({super.key, required this.callId, required this.language});

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  static const int _maxVisibleSuggestions = 6;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  WebSocketChannel? _channel;
  bool _isCallConnected = false; // 통화 연결 상태 확인용 변수
  List<String> _currentSuggestions = [];
  bool _isSuggestionVisible = false;

  // --- Suggestions State ---
  List<String> _serverSuggestions = [];
  final List<String> _defaultSuggestions = [
    '안녕하세요, 예약하려고 하는데요.',
    '오늘 저녁 7시에 2명 예약 가능한가요?',
    '혹시 주차 가능한가요?',
    '영업 시간이 어떻게 되나요?',
    '네, 알겠습니다.',
    '잠시만 기다려주세요.',
    '잘 못 들었습니다.',
    '감사합니다.',
  ];

  // --- Hangul Chosung Logic ---
  final List<String> _chosungList = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  String _extractChosung(String text) {
    String result = '';
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // 한글 유니코드 범위: 0xAC00 ~ 0xD7A3
      if (code >= 0xAC00 && code <= 0xD7A3) {
        int chosungIndex = ((code - 0xAC00) ~/ 28) ~/ 21;
        result += _chosungList[chosungIndex];
      } else {
        result += text[i];
      }
    }
    return result;
  }

  // [UX 개선] 입력된 텍스트를 분석하여 상황에 맞는 문장을 동적으로 생성
  List<String> _generateDynamicSuggestions(String query) {
    final suggestions = <String>[];

    // 1. 숫자 추출 (예: "6", "4")
    final numbers = RegExp(
      r'\d+',
    ).allMatches(query).map((m) => m.group(0)!).toList();

    // 2. 키워드 감지
    final hasStore = query.contains('가게') || query.contains('식당');

    // Case 1: "가게"만 입력 시
    if (hasStore && numbers.isEmpty) {
      suggestions.add('가게 예약하고 싶어서요.');
      suggestions.add('혹시 가게 위치가 어디인가요?');
    }

    // Case 2: 숫자 감지 (시간/인원 추론)
    if (numbers.isNotEmpty) {
      if (numbers.length == 1) {
        final n = numbers[0];
        // 숫자가 하나면 시간이나 인원으로 추론
        suggestions.add('오늘 저녁 $n시에 예약하고 싶어요.');
        suggestions.add('$n명 예약 가능한가요?');
        if (hasStore) suggestions.add('가게에 $n시쯤 도착할 것 같아요.');
      } else if (numbers.length >= 2) {
        final n1 = numbers[0];
        final n2 = numbers[1];
        // 숫자가 두 개면 [시간, 인원] 순서로 추론 (예: "6 4" -> 6시 4명)
        suggestions.add('오늘 $n1시에 $n2명 예약하고 싶어요.');
        suggestions.add('내일 $n1시, $n2명 자리 있나요?');
      }
    }

    return suggestions;
  }

  List<String> _getSuggestions(String query) {
    // 0. 사용자 설정 문구 가져오기
    final customPhrases = ref.read(customPhrasesProvider);

    // 1. 정적 추천 목록 (사용자 설정 + 서버 + 기본)
    final staticSuggestions = {
      ...customPhrases, // 사용자가 등록한 문구를 최우선으로 배치
      ..._serverSuggestions,
      ..._defaultSuggestions,
    }.toList();

    if (query.isEmpty) return staticSuggestions;

    // 2. 동적 추천 생성 (입력값 기반)
    final dynamicSuggestions = _generateDynamicSuggestions(query);

    // 3. 정적 목록 필터링
    final cleanQuery = query.replaceAll(RegExp(r'[\s,.\?!]'), '');
    final filteredStatic = staticSuggestions.where((s) {
      final cleanSuggestion = s.replaceAll(RegExp(r'[\s,.\?!]'), '');
      return cleanSuggestion.contains(cleanQuery) ||
          _extractChosung(cleanSuggestion).contains(cleanQuery);
    }).toList();

    // 4. 동적 추천을 최상단에 배치하여 합침
    return [...dynamicSuggestions, ...filteredStatic];
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    if (widget.callId == 'test_mode') {
      // [테스트 모드] 웹소켓 연결 없이 UI 초기화
      setState(() {
        _isCallConnected = true;
        _messages.add(
          Message(
            original: 'System',
            translated: '테스트 모드입니다. (서버 연결 없음)',
            isFromUser: false,
          ),
        );
        _serverSuggestions = ['테스트 답변 1', '테스트 답변 2', '네, 알겠습니다.', '가게 예약'];
        _updateSuggestions();
      });
    } else {
      _connectWebSocket();
    }
  }

  void _onTextChanged() {
    _updateSuggestions();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() {
        _isSuggestionVisible = true;
      });
      _updateSuggestions();
    }
  }

  void _updateSuggestions() {
    setState(() {
      _currentSuggestions = _getSuggestions(
        _textController.text,
      ).take(_maxVisibleSuggestions).toList();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _connectWebSocket() {
    final backendClient = ref.read(backendClientProvider);
    final wsUrl = backendClient.buildWebSocketUrl('/ws/app/${widget.callId}');
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
                  refined: data['refined'], // [추가] 보정 데이터 수신
                  isFromUser: false,
                ),
              );
              _scrollToBottom();
            } else if (data['type'] == 'suggestions_update') {
              // [UX 최적화] 추천 답변이 도착하면 리스트 갱신
              if (data['suggestions'] != null) {
                _serverSuggestions = List<String>.from(data['suggestions']);
                if (_isSuggestionVisible) {
                  _updateSuggestions();
                }
              }
            } else if (data['type'] == 'user_text') {
              _applyUserTranslation(
                original: data['original'],
                translated: data['translated'],
                messageId: data['message_id'],
              );
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
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _applyUserTranslation({
    required String original,
    required String translated,
    String? messageId,
  }) {
    // 이전 서버는 ID 없이 번역을 보낸 순서대로 돌려준다.
    final index = _messages.indexWhere(
      (message) => messageId == null
          ? message.pendingId != null && message.original == original
          : message.pendingId == messageId,
    );
    if (index == -1) return;
    _messages[index] = Message(
      original: _messages[index].original,
      translated: translated,
      isFromUser: true,
    );
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    // 테스트 모드가 아닐 때만 채널 연결 확인
    if (widget.callId != 'test_mode' && _channel == null) return;
    _textController.clear();
    final messageId = const Uuid().v4();

    setState(() {
      _messages.add(
        Message(
          original: text,
          translated: '(Sending...)',
          isFromUser: true,
          pendingId: messageId,
        ),
      );
      _scrollToBottom();
      _isSuggestionVisible = false; // 전송 후 자동완성 숨김
    });

    // [테스트 모드] 가짜 응답 시뮬레이션
    if (widget.callId == 'test_mode') {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            // 1. 내 메시지 번역 완료 처리
            _applyUserTranslation(
              original: text,
              translated: '$text (번역됨)',
              messageId: messageId,
            );
            // 2. 상대방 가짜 응답 추가
            _messages.add(
              Message(
                original: 'Echo: $text',
                translated: '에코: $text',
                refined: 'AI 추측: $text (보정됨)', // 테스트용 가짜 보정
                isFromUser: false,
              ),
            );
            _scrollToBottom();
          });
        }
      });
      return;
    }

    final message = jsonEncode({
      'event': 'frontend_text',
      'message_id': messageId,
      'text': text,
    });
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
      body: SafeArea(
        child: !_isCallConnected
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
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ListTile(
                          title: Text(
                            message.original,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.translated,
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                              ),
                              // [UX 개선] 보정된 텍스트가 있으면 표시
                              if (message.refined != null &&
                                  message.refined != message.translated)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '✨ AI 추측: ${message.refined}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
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
                  _buildSuggestionBar(),
                  Material(
                    color: Theme.of(context).cardColor,
                    elevation: 6,
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
      ),
    );
  }

  Widget _buildSuggestionBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      alignment: Alignment.topCenter,
      child: (!_isSuggestionVisible || _currentSuggestions.isEmpty)
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              height: 72.0,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50, // Subtle background contrast
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _currentSuggestions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10.0),
                itemBuilder: (context, index) {
                  final suggestion = _currentSuggestions[index];
                  return _SuggestionChip(
                    suggestion: suggestion,
                    onTap: () {
                      _textController.text = suggestion;
                      _textController.selection = TextSelection.collapsed(
                        offset: suggestion.length,
                      );
                      _updateSuggestions();
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: _handleSubmitted,
                  onTap: () {
                    setState(() {
                      _isSuggestionVisible = true;
                    });
                    _updateSuggestions();
                  },
                  onChanged: (text) {
                    setState(() {
                      _isSuggestionVisible = true;
                    });
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Send a message',
                  ),
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.suggestion, required this.onTap});

  final String suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  suggestion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
