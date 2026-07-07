import 'package:flutter_test/flutter_test.dart';
import 'package:main_project_app/src/core/network/backend_client.dart';

void main() {
  test('BackendClient normalizes HTTP and WebSocket URLs', () {
    final client = BackendClient(baseUrl: 'api.example.com');

    expect(client.buildUri('/call'), Uri.parse('https://api.example.com/call'));
    expect(
      client.buildWebSocketUrl('/ws/app/call-id'),
      'wss://api.example.com/ws/app/call-id',
    );
  });
}
