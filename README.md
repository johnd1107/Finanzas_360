# Finanzas360

Aplicación de finanzas personales con frontend Flutter y API REST Node.js/Express.

## Requisitos

- Flutter y Dart según las versiones de `pubspec.yaml`.
- Node.js 20 o posterior.
- Android SDK para ejecutar en emulador o dispositivo Android.

## Ejecutar el backend

Desde la raíz del repositorio:

```powershell
cd backend
npm install
npm start
```

El backend escucha en `http://localhost:3000`.

## Ejecutar en el emulador Android

En otra terminal, desde la raíz del repositorio:

```powershell
flutter pub get
adb -s emulator-5554 reverse tcp:3000 tcp:3000
flutter run -d emulator-5554 --android-skip-build-dependency-validation
```

Repite el comando `adb reverse` para cada emulador conectado, sustituyendo su identificador. En un teléfono físico, configura una URL accesible desde el teléfono con `--dart-define=API_BASE_URL=http://<IP-del-equipo>:3000`.

## Cuentas de demostración

- Administrador: usuario `admin`, contraseña `1234`.
- Cliente: cédula `1234567890`, contraseña `Cliente12345`.
- Cliente: cédula `0987654321`, contraseña `Maria12345`.
- Cajero: usuario `cajero001`, contraseña `Cajero12345`.

Cambia estas credenciales antes de usar el sistema fuera de un entorno de demostración.

## Verificaciones

```powershell
flutter analyze
flutter test
node --check backend/server.js
```

## Persistencia

El servidor actual mantiene las cuentas, saldos, sesiones y operaciones en memoria. Se reinician al detener Node.js. Las fotos cargadas se almacenan en `backend/uploads/` y no se versionan.
