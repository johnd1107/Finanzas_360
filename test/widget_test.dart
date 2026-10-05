// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_360/core/config/app_config.dart';
import 'package:finanzas_360/main.dart';

void main() {
  testWidgets('login solo muestra usuario y contraseña', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Cédula / Usuario'), findsOneWidget);
    expect(
      find.text(AppConfig.testMode ? 'Contraseña de prueba: ${AppConfig.testPassword}' : 'Contraseña'),
      findsOneWidget,
    );
    expect(find.text('Toca la foto para usar Cámara o Galería'), findsNothing);
    expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
  });

  testWidgets('login rechaza claves de menos de diez caracteres', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('INGRESAR AL SISTEMA'));
    await tester.pump();

    expect(find.text('La contraseña debe tener al menos 10 caracteres'), findsOneWidget);
  });

  testWidgets('el enlace abre el formulario de registro', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    final registerLink = find.text('¿No tienes cuenta? Regístrate aquí');
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    expect(find.text('Nombre Completo'), findsOneWidget);
    expect(find.text('Cédula / Usuario'), findsOneWidget);
  });

  testWidgets('el modo demo abre contenido de ejemplo sin iniciar sesión', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Entrar en modo demostración'));
    await tester.tap(find.text('Entrar en modo demostración'));
    await tester.pumpAndSettle();

    expect(find.text('Finanzas 360 · Demo'), findsOneWidget);
    expect(find.text('Juan Pérez'), findsOneWidget);
    expect(find.text('\$2,450.00'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Sucursales'), findsOneWidget);
  });

  if (AppConfig.testMode) {
    testWidgets('modo de pruebas rechaza cédulas que no tengan diez dígitos', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('¿No tienes cuenta? Regístrate aquí'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre Completo'), 'Persona de prueba');
      await tester.enterText(find.widgetWithText(TextFormField, 'Cédula / Usuario'), '123456789');
      await tester.tap(find.text('REGISTRARME'));
      await tester.pump();

      expect(find.text('Ingrese 10 dígitos; no se valida la cédula'), findsOneWidget);
      expect(find.text('Clave común de pruebas'), findsOneWidget);
    });
  }
}
