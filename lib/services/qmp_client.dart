import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Error reported by the QMP server for a specific command
/// (e.g. `DeviceNotActive` when no balloon device exists).
class QmpException implements Exception {
  final String errorClass;
  final String description;

  QmpException(this.errorClass, this.description);

  @override
  String toString() => 'QMP $errorClass: $description';
}

/// Cumulative per-device block counters from `query-blockstats`.
class BlockStats {
  final String device;
  final int readBytes;
  final int writeBytes;

  const BlockStats(this.device, this.readBytes, this.writeBytes);
}

/// Minimal QEMU Machine Protocol client over a unix socket.
///
/// Handshake follows docs/interop/qmp-spec.json: the server sends a greeting
/// line, the client replies with `qmp_capabilities`, after that commands are
/// newline-delimited JSON objects. Events (no `id` field) are ignored.
class QmpClient {
  QmpClient(this.socketPath);

  final String socketPath;

  Socket? _socket;
  StreamSubscription<String>? _subscription;
  final Map<int, Completer<Object?>> _pending = {};
  Completer<void>? _greeting;
  bool _handshaken = false;
  int _nextId = 0;

  bool get isConnected => _handshaken;

  Future<void> connect({Duration timeout = const Duration(seconds: 3)}) async {
    if (_handshaken) return;
    final socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
      timeout: timeout,
    );
    _socket = socket;
    _greeting = Completer<void>();
    _subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onError: _fail,
          onDone: () => _fail(StateError('QMP socket closed')),
        );
    try {
      await _greeting!.future.timeout(timeout);
      await execute('qmp_capabilities').timeout(timeout);
      _handshaken = true;
    } catch (e) {
      disconnect();
      rethrow;
    }
  }

  /// Sends a command and resolves with the decoded `return` payload
  /// (may be a map, a list or null). Rejects with [QmpException] on error.
  Future<Object?> execute(String command, [Map<String, dynamic>? arguments]) {
    final socket = _socket;
    if (socket == null) {
      return Future.error(StateError('QMP client not connected'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    final msg = <String, dynamic>{'execute': command, 'id': id};
    if (arguments != null) msg['arguments'] = arguments;
    socket.writeln(jsonEncode(msg));
    return completer.future
        .timeout(const Duration(seconds: 2))
        .catchError((Object e) {
      _pending.remove(id);
      throw e;
    });
  }

  /// Current balloon value in bytes, or null if the guest reports none.
  /// Throws [QmpException] (DeviceNotActive) when no balloon device exists.
  Future<int?> queryBalloon() async {
    final ret = await execute('query-balloon');
    if (ret is Map) {
      final actual = ret['actual'];
      if (actual is num) return actual.toInt();
    }
    return null;
  }

  /// Cumulative block device counters; sum deltas between two calls to get
  /// read/write throughput.
  Future<List<BlockStats>> queryBlockstats() async {
    final ret = await execute('query-blockstats');
    if (ret is! List) return const [];
    final result = <BlockStats>[];
    for (final entry in ret) {
      if (entry is! Map) continue;
      final stats = entry['stats'];
      if (stats is! Map) continue;
      final rd = (stats['rd_bytes'] as num?)?.toInt() ?? 0;
      final wr = (stats['wr_bytes'] as num?)?.toInt() ?? 0;
      result.add(BlockStats(entry['device']?.toString() ?? '', rd, wr));
    }
    return result;
  }

  void _handleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return; // not JSON, ignore
    }
    if (decoded is! Map) return;

    if (decoded.containsKey('QMP')) {
      final greeting = _greeting;
      _greeting = null;
      if (greeting != null && !greeting.isCompleted) greeting.complete();
      return;
    }
    if (decoded.containsKey('event')) {
      return; // async events are not used by the monitor
    }
    final id = decoded['id'];
    if (id is int && _pending.containsKey(id)) {
      final completer = _pending.remove(id)!;
      if (decoded.containsKey('error')) {
        final err = decoded['error'];
        final errorClass =
            err is Map ? err['class']?.toString() ?? 'Unknown' : 'Unknown';
        final desc = err is Map ? err['desc']?.toString() ?? '' : '';
        if (!completer.isCompleted) {
          completer.completeError(QmpException(errorClass, desc));
        }
      } else if (!completer.isCompleted) {
        completer.complete(decoded['return']);
      }
    }
  }

  void _fail(Object error) {
    _handshaken = false;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    final greeting = _greeting;
    _greeting = null;
    if (greeting != null && !greeting.isCompleted) {
      greeting.completeError(error);
    }
  }

  void disconnect() {
    _handshaken = false;
    _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _fail(StateError('QMP client disconnected'));
  }
}
