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

## Probar y compartir la app

- **Modo demostración:** abre la app y elige `Entrar en modo demostración`. Muestra movimientos y sucursales de ejemplo, funciona sin servidor y no modifica datos.
- **Modo de pruebas con backend:** detén cualquier servidor anterior con `Ctrl+C`. En PowerShell, activa el modo de pruebas y arranca el backend:

```powershell
$env:TEST_MODE = 'true'
npm --prefix backend start
```

En otra terminal, compila el APK con `TEST_MODE=true` y la IP Wi-Fi actual del PC:

```powershell
flutter build apk --release --dart-define=TEST_MODE=true --dart-define=API_BASE_URL=http://<IP-del-equipo>:3000
```

En modo de pruebas, las cuentas de cliente y cajero usan la clave común `1725959983`; el identificador debe tener exactamente 10 dígitos, sin validar el checksum de la cédula. El administrador de prueba usa la misma clave. El modo normal no aplica estas reglas y no debe usarse con la clave común; el backend bloquea `TEST_MODE` si `NODE_ENV=production`.

Comparte `build/app/outputs/flutter-apk/app-release.apk`. Para iniciar sesión y usar el modo completo, cada celular debe estar conectado a la misma Wi-Fi que el PC, el backend debe seguir ejecutándose y el firewall de Windows debe permitir Node.js/puerto 3000. La IP local puede cambiar; si cambia, hay que compilar otra vez. Fuera de esa red solo funciona la demostración sin servidor. Para conectar desde cualquier red hace falta publicar el backend en Internet.

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
