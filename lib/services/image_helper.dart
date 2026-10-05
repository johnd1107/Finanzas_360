import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<void> seleccionarImagen(
    BuildContext context,
    Future<void> Function(XFile) onImagenSeleccionada,
  ) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar foto con la cámara'),
              onTap: () async {
                try {
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  await _procesarCaptura(context, ImageSource.camera, onImagenSeleccionada);
                } catch (error) {
                  if (context.mounted) _mostrarErrorCaptura(context, error);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Buscar en galería / archivos'),
              onTap: () async {
                try {
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  await _procesarCaptura(context, ImageSource.gallery, onImagenSeleccionada);
                } catch (error) {
                  if (context.mounted) _mostrarErrorCaptura(context, error);
                }
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
    try {
      final permiso = origen == ImageSource.camera ? Permission.camera : Permission.photos;
      final status = await permiso.request();
      if (!context.mounted) return;

      if (!status.isGranted && !status.isLimited) {
        await _mostrarAlertaPermiso(context);
        return;
      }

      final XFile? imagen = await _picker.pickImage(source: origen, imageQuality: 80);
      if (!context.mounted || imagen == null) return;

      final path = imagen.path.trim();
      if (path.isEmpty || !await File(path).exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo acceder a la fotografía seleccionada')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      await _confirmarSubida(context, imagen, onConfirmada);
    } catch (error) {
      if (context.mounted) _mostrarErrorCaptura(context, error);
    }
  }

  static Future<void> _confirmarSubida(
    BuildContext context,
    XFile imagen,
    Future<void> Function(XFile) onConfirmada,
  ) async {
    await showDialog<void>(
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
              try {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                await onConfirmada(imagen);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo procesar la fotografía: $error')),
                  );
                }
              }
            },
            child: const Text('Aceptar y Subir'),
          ),
        ],
      ),
    );
  }

  static Future<void> _mostrarAlertaPermiso(BuildContext context) async {
    await showDialog<void>(
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

  static void _mostrarErrorCaptura(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo abrir la cámara o galería: $error')),
    );
  }
}
