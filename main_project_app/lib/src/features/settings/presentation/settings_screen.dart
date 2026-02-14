import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_project_app/src/features/settings/application/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _greetingController;
  final TextEditingController _phraseController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // 현재 저장된 인삿말을 가져와서 입력창 초기값으로 설정
    final currentGreeting = ref.read(greetingProvider);
    _greetingController = TextEditingController(text: currentGreeting);
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _phraseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(languageProvider);
    final currentVoice = ref.watch(voiceProvider);
    final customPhrases = ref.watch(customPhrasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Target Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currentLanguage,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['English', 'Japanese', 'Chinese', 'Spanish', 'Dutch']
                .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(languageProvider.notifier).setLanguage(value);
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'AI Voice',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currentVoice,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']
                .map(
                  (voice) => DropdownMenuItem(
                    value: voice,
                    child: Text(voice.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value != null) {
                ref.read(voiceProvider.notifier).setVoice(value);

                // 목소리 미리듣기 재생
                final greeting = ref.read(greetingProvider);
                if (greeting.isNotEmpty) {
                  final bytes = await ref
                      .read(voicePreviewProvider)
                      .fetchPreview(greeting, value);

                  // [검증 보완] 비동기 요청 후 위젯이 여전히 존재하는지 확인
                  if (!mounted) return;

                  if (bytes != null) {
                    await _audioPlayer.stop(); // 기존 재생 중지
                    await _audioPlayer.play(BytesSource(bytes));
                  }
                }
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Greeting Message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This message will be spoken to the recipient when they answer.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _greetingController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your greeting message here...',
            ),
            onChanged: (value) {
              // 입력할 때마다 바로 저장 (간단한 구현)
              ref.read(greetingProvider.notifier).setGreeting(value);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Custom Phrases (자주 쓰는 문구)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phraseController,
                  decoration: const InputDecoration(
                    hintText: 'Add a new phrase...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  if (_phraseController.text.isNotEmpty) {
                    ref
                        .read(customPhrasesProvider.notifier)
                        .addPhrase(_phraseController.text);
                    _phraseController.clear();
                  }
                },
                icon: const Icon(
                  Icons.add_circle,
                  size: 32,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: customPhrases.map((phrase) {
              return Chip(
                label: Text(phrase),
                onDeleted: () {
                  ref.read(customPhrasesProvider.notifier).removePhrase(phrase);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
