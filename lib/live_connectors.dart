import 'dart:async';
import 'package:flutter/foundation.dart';
import 'actions_studio.dart';
import 'platform_logos.dart';

class HellLiveConnectorsManager {
  final Set<String> _processedEventIds = {};
  final Map<String, Timer> _activePollers = {};
  bool obsConnected = false;
  String obsCurrentScene = 'Cena Principal (Jogo)';

  bool _isDuplicate(String eventId) {
    if (_processedEventIds.contains(eventId)) return true;
    _processedEventIds.add(eventId);
    if (_processedEventIds.length > 500) {
      _processedEventIds.remove(_processedEventIds.first);
    }
    return false;
  }

  void syncPlatformConnection({
    required PlatformAccountConfig platform,
    required Function(HellLiveEvent) onEventReceived,
  }) {
    _activePollers[platform.id]?.cancel();
    _activePollers.remove(platform.id);

    if (!platform.isConnected || !platform.hasCredentials) {
      return;
    }

    // Monitoriza estado de ligação da plataforma ativa (respeitando limites da API)
    _activePollers[platform.id] = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        if (!platform.isConnected) return;
        final heartbeatId = '${platform.id}_hb_${DateTime.now().minute}';
        if (_isDuplicate(heartbeatId)) return;
        debugPrint('[HELL Connector] ${platform.name} (${platform.usernameOrKey}) ativo.');
      },
    );
  }

  void dispatchExternalEvent({
    required HellLiveEvent event,
    required Function(HellLiveEvent) onAcceptedEvent,
  }) {
    if (_isDuplicate(event.id)) return;
    onAcceptedEvent(event);
  }

  void switchObsScene(String sceneName) {
    obsConnected = true;
    obsCurrentScene = sceneName;
  }

  void disposeAll() {
    for (final timer in _activePollers.values) {
      timer.cancel();
    }
    _activePollers.clear();
  }
}
