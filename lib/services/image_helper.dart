import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static void seleccionarImagen(BuildContext context, Future<void> Function(XFile) onImagenSeleccionada) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _procesarCaptura(context, ImageSource.camera, onImagenSeleccionada);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Buscar en galería / archivos'),
              onTap: () {
                Navigator.pop(ctx);
                _procesarCaptura(context, ImageSource.gallery, onImagenSeleccionada);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _procesarCaptura(
    BuildContext context,
    ImageSource origen,
    Future<void> Function(XFile) onConfirmada,
  ) async {
    Permission permiso = (origen == ImageSource.camera) ? Permission.camera : Permission.photos;
    PermissionStatus status = await permiso.request();

    if (!status.isGranted && !status.isLimited) {
      if (context.mounted) _mostrarAlertaPermiso(context);
      return;
    }

    final XFile? imagen = await _picker.pickImage(source: origen, imageQuality: 80);

    if (imagen != null && context.mounted) {
      _confirmarSubida(context, imagen, onConfirmada);
    }
  }

  static void _confirmarSubida(
    BuildContext context,
    XFile imagen,
    Future<void> Function(XFile) onConfirmada,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Está seguro?'),
        content: const Text('¿Desea subir esta fotografía al sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await onConfirmada(imagen);
            },
            child: const Text('Aceptar y Subir'),
          ),
        ],
      ),
    );
  }

  static void _mostrarAlertaPermiso(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso Requerido'),
        content: const Text(
          'Se requieren permisos de cámara/galería/notificaciones para continuar',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ir a Ajustes'),
          ),
        ],
      ),
    );
  }
}
