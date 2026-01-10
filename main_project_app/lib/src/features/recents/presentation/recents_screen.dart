import 'package:flutter/material.dart';

class RecentCall {
  final String name;
  final String time;
  final bool wasAiProcessed;

  RecentCall({
    required this.name,
    required this.time,
    this.wasAiProcessed = false,
  });
}

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<RecentCall> recentCalls = [
      RecentCall(name: 'John Doe', time: '10:30 AM', wasAiProcessed: true),
      RecentCall(name: 'Jane Smith', time: 'Yesterday'),
      RecentCall(name: 'Peter Jones', time: 'Wednesday', wasAiProcessed: true),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: recentCalls.length,
          itemBuilder: (context, index) {
            final call = recentCalls[index];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(call.name),
              subtitle: Text(call.time),
              trailing: call.wasAiProcessed
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome),
                        TextButton(
                          onPressed: () {
                            // TODO: Implement view summary
                          },
                          child: const Text('View Summary'),
                        ),
                      ],
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}
