import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> solicitarPermiso(BuildContext context) async {
    if (kIsWeb) return true;
    final status = await Permission.notification.request();
    if (status.isGranted) return true;
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: const Text(
            'Se requieren permisos de cámara/galería/notificaciones para continuar',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAppSettings();
              },
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  static Future<void> mostrarNotificacion({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    if (kIsWeb) {
      debugPrint('[NOTIFICACIÓN] $titulo - $cuerpo');
      return;
    }
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'transferencias_finanzas360',
        'Transferencias',
        channelDescription: 'Avisos de transferencias recibidas y enviadas',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id: id, title: titulo, body: cuerpo, notificationDetails: details);
  }
}
