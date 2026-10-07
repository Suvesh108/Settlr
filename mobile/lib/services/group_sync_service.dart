import 'dart:async';
import 'dart:io';
import 'api_service.dart';

/// Real-time collaborative group ledger sync service via WebSocket & background polling.
/// Provides 1:1 parity with the webapp's useGroupSync hook.
class GroupSyncService {
  static final GroupSyncService instance = GroupSyncService._();
  GroupSyncService._();

  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  String? _currentGroupId;
  bool _isConnecting = false;

  final StreamController<String> _syncEventController =
      StreamController<String>.broadcast();

  /// Stream emitting when remote group changes occur
  Stream<String> get onSyncEvent => _syncEventController.stream;

  /// Connect to the active group's live WebSocket room
  void connect(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      disconnect();
      return;
    }

    if (_currentGroupId == groupId && _socket != null) {
      return; // Already actively connected
    }

    disconnect();
    _currentGroupId = groupId;
    _establishConnection();

    // Periodic catch-up polling every 15s (matching webapp TanStack Query refetchOnReconnect)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _syncEventController.add('poll_tick');
    });
  }

  Future<void> _establishConnection() async {
    if (_isConnecting || _currentGroupId == null) return;
    _isConnecting = true;

    try {
      final token = ApiService.token;
      final baseUrl = ApiService.baseUrl;

      final uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = Uri(
        scheme: wsScheme,
        host: uri.host,
        port: uri.port,
        path: '/ws/groups/$_currentGroupId',
        queryParameters: token != null ? {'token': token} : null,
      );

      _socket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 4));
      _isConnecting = false;

      _socket!.listen(
        (data) {
          try {
            // Received broadcast from backend (e.g. expense.created, settlement.recorded)
            _syncEventController.add('remote_update');
          } catch (_) {}
        },
        onDone: () {
          _scheduleReconnect();
        },
        onError: (_) {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _syncEventController.add('connected');
    } catch (_) {
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socket = null;
    _reconnectTimer?.cancel();
    if (_currentGroupId != null) {
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        if (_currentGroupId != null) {
          _establishConnection();
        }
      });
    }
  }

  /// Disconnect current WebSocket and stop polling
  void disconnect() {
    _currentGroupId = null;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _isConnecting = false;
  }
}
