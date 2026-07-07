import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_project_app/src/features/settings/application/settings_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _greetingController;
  final TextEditingController _phraseController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false; // 재생 상태 관리

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

  Future<void> _playPreview() async {
    final greeting = _greetingController.text.trim();
    final voice = ref.read(voiceProvider);

    if (greeting.isEmpty) return;

    await ref.read(greetingProvider.notifier).setGreeting(greeting);

    setState(() => _isPlaying = true);

    try {
      final preview = await ref
          .read(voicePreviewProvider)
          .fetchPreview(greeting, voice);

      if (!mounted) return;

      if (preview != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(
          BytesSource(preview.bytes, mimeType: preview.mimeType),
        );
      }
    } catch (e) {
      debugPrint('Preview error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(languageProvider);
    final currentVoice = ref.watch(voiceProvider);
    final customPhrases = ref.watch(customPhrasesProvider);
    final currentGreeting = ref.watch(greetingProvider);

    if (_greetingController.text != currentGreeting) {
      _greetingController.value = TextEditingValue(
        text: currentGreeting,
        selection: TextSelection.collapsed(offset: currentGreeting.length),
      );
    }

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
            initialValue: currentLanguage,
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: currentVoice,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: ['alloy', 'echo', 'shimmer']
                      .map(
                        (voice) => DropdownMenuItem(
                          value: voice,
                          child: Text(voice.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(voiceProvider.notifier).setVoice(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isPlaying ? null : _playPreview,
                icon: _isPlaying
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up, size: 30),
                color: Colors.blue,
                tooltip: 'Preview Voice',
              ),
            ],
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
