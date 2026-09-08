import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qemu_gui/services/qmp_client.dart';

/// A tiny fake QMP server: sends the greeting line and answers
/// qmp_capabilities / query-balloon / query-blockstats by id.
class FakeQmpServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];

  /// When set, query-balloon is answered with an error response.
  String? balloonErrorClass;

  Future<void> start(String socketPath) async {
    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    _server!.listen((socket) {
      _clients.add(socket);
      socket.writeln(jsonEncode({
        'QMP': {
          'version': {
            'qemu': {'major': 10, 'minor': 2, 'micro': 0},
            'package': 'test',
          },
          'capabilities': [],
        },
      }));
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _handleLine(socket, line));
    });
  }

  void _handleLine(Socket socket, String line) {
    if (line.trim().isEmpty) return;
    final msg = jsonDecode(line) as Map;
    final id = msg['id'];
    switch (msg['execute']) {
      case 'qmp_capabilities':
        socket.writeln(jsonEncode({'return': {}, 'id': id}));
      case 'query-balloon':
        if (balloonErrorClass != null) {
          socket.writeln(jsonEncode({
            'error': {'class': balloonErrorClass, 'desc': 'no balloon'},
            'id': id,
          }));
        } else {
          socket.writeln(jsonEncode({
            'return': {'actual': 268435456},
            'id': id,
          }));
        }
      case 'query-blockstats':
        socket.writeln(jsonEncode({
          'return': [
            {
              'device': 'drive0',
              'stats': {'rd_bytes': 2048, 'wr_bytes': 1024},
            },
            {
              'device': 'ide2-cd0',
              'stats': {'rd_bytes': 0, 'wr_bytes': 0},
            },
          ],
          'id': id,
        }));
    }
  }

  Future<void> stop() async {
    await _server?.close();
    for (final socket in _clients) {
      socket.destroy();
    }
  }
}

void main() {
  late Directory tmpDir;
  late String socketPath;
  late FakeQmpServer server;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qmp_client_test');
    socketPath = '${tmpDir.path}/vm.qmp.sock';
    server = FakeQmpServer();
    await server.start(socketPath);
  });

  tearDown(() async {
    await server.stop();
    await tmpDir.delete(recursive: true);
  });

  test('handshake and query-balloon round trip', () async {
    final client = QmpClient(socketPath);
    await client.connect();
    expect(await client.queryBalloon(), 268435456);
    client.disconnect();
  });

  test('query-blockstats parses cumulative counters', () async {
    final client = QmpClient(socketPath);
    await client.connect();
    final stats = await client.queryBlockstats();
    expect(stats, hasLength(2));
    expect(stats[0].device, 'drive0');
    expect(stats[0].readBytes, 2048);
    expect(stats[0].writeBytes, 1024);
    expect(stats[1].readBytes, 0);
    client.disconnect();
  });

  test('error responses surface as QmpException', () async {
    server.balloonErrorClass = 'DeviceNotActive';
    final client = QmpClient(socketPath);
    await client.connect();
    await expectLater(
      client.queryBalloon(),
      throwsA(isA<QmpException>()
          .having((e) => e.errorClass, 'errorClass', 'DeviceNotActive')),
    );
    client.disconnect();
  });

  test('connect fails cleanly when no server listens', () async {
    final client = QmpClient('${tmpDir.path}/missing.sock');
    await expectLater(client.connect(), throwsA(anything));
    expect(client.isConnected, isFalse);
  });
}
