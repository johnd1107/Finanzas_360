import 'package:flutter/material.dart';

class DemoView extends StatelessWidget {
  const DemoView({super.key});

  static const _movimientos = [
    ('Depósito recibido', 'María López · Hoy, 10:42', 180.00, true),
    ('Pago de servicio', 'Electricidad · Ayer, 16:15', 62.50, false),
    ('Transferencia recibida', 'Carlos Ruiz · 1 oct', 95.00, true),
    ('Compra', 'Mercado Central · 30 sep', 34.75, false),
  ];

  static const _sucursales = [
    ('Sucursal Centro', 'Av. Central 120', 'Lun-Vie · 08:00-17:00'),
    ('Sucursal Norte', 'Calle Norte 45', 'Lun-Vie · 08:30-16:30'),
    ('Sucursal Sur', 'Av. del Parque 210', 'Lun-Sáb · 09:00-14:00'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finanzas 360 · Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Movimientos'),
              Tab(text: 'Sucursales'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ResumenDemo(),
            _MovimientosDemo(),
            _SucursalesDemo(),
          ],
        ),
      ),
    );
  }
}

class _ResumenDemo extends StatelessWidget {
  const _ResumenDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Juan Pérez', style: Theme.of(context).textTheme.titleLarge),
        const Text('Cuenta de demostración'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo disponible'),
                const SizedBox(height: 8),
                Text('\$2,450.00', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('••••  7890'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Actividad reciente', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...DemoView._movimientos.take(3).map((movimiento) => _MovimientoTile(movimiento: movimiento)),
      ],
    );
  }
}

class _MovimientosDemo extends StatelessWidget {
  const _MovimientosDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: DemoView._movimientos
          .map((movimiento) => _MovimientoTile(movimiento: movimiento))
          .toList(),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento});

  final (String, String, double, bool) movimiento;

  @override
  Widget build(BuildContext context) {
    final (titulo, detalle, monto, ingreso) = movimiento;
    final color = ingreso ? Colors.teal.shade700 : Colors.deepOrange.shade700;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(ingreso ? Icons.south_west : Icons.north_east, color: color),
      ),
      title: Text(titulo),
      subtitle: Text(detalle),
      trailing: Text(
        '${ingreso ? '+' : '-'}\$${monto.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SucursalesDemo extends StatelessWidget {
  const _SucursalesDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: DemoView._sucursales
          .map(
            (sucursal) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)),
              title: Text(sucursal.$1),
              subtitle: Text('${sucursal.$2}\n${sucursal.$3}'),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}