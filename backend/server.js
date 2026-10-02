const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, 'uploads')),
  filename: (req, file, cb) => cb(null, Date.now() + path.extname(file.originalname))
});
const upload = multer({ storage });

let usuarios = [
  { cedula: "1234567890", nombre: "Juan Pérez", email: "juan@email.com", saldo: 2450.00, fotoUrl: "", rol: "cliente" },
  { cedula: "0987654321", nombre: "María López", email: "maria@email.com", saldo: 5120.50, fotoUrl: "", rol: "cliente" }
];

const cajeros = [
  { cedula: "cajero001", nombre: "Lucía Torres", email: "lucia@finanzas360.local", saldo: 0, fotoUrl: "", rol: "cajero", sucursal: "Sucursal Centro" }
];
const administradores = [
  { cedula: "admin", usuario: "admin", aliases: ["administrador"], nombre: "Administrador", email: "admin@finanzas360.local", saldo: 0, fotoUrl: "", rol: "administrador" }
];
const sucursales = [
  { id: "centro", nombre: "Sucursal Centro", direccion: "Av. Central 120", servicios: ["Depósitos", "Retiros"] },
  { id: "norte", nombre: "Sucursal Norte", direccion: "Calle Norte 45", servicios: ["Depósitos", "Retiros"] }
];
const credenciales = new Map();
const sesiones = new Map();
let transferencias = [];
let notificaciones = [];
let operaciones = [];
let siguienteTransferenciaId = 1;
let siguienteNotificacionId = 1;
let siguienteOperacionId = 1;

function normalizarIdentificador(valor) {
  return String(valor || '').trim().toLowerCase();
}

function guardarClave(identificador, clave) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(clave, salt, 64);
  credenciales.set(normalizarIdentificador(identificador), { salt, hash });
}

function validarClave(identificador, clave) {
  const credencial = credenciales.get(normalizarIdentificador(identificador));
  if (!credencial) return false;
  const intento = crypto.scryptSync(clave, credencial.salt, 64);
  return crypto.timingSafeEqual(credencial.hash, intento);
}

function buscarPersona(identificador) {
  const buscado = normalizarIdentificador(identificador);
  return [...usuarios, ...cajeros, ...administradores].find(
    (persona) => normalizarIdentificador(persona.cedula) === buscado ||
      normalizarIdentificador(persona.usuario) === buscado ||
      (persona.aliases || []).some((alias) => normalizarIdentificador(alias) === buscado)
  );
}

guardarClave('1234567890', 'Cliente12345');
guardarClave('0987654321', 'Maria12345');
guardarClave('cajero001', 'Cajero12345');
guardarClave('admin', '1234');
guardarClave('administrador', '1234');

function autenticar(...rolesPermitidos) {
  return (req, res, next) => {
    const token = (req.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const cedula = sesiones.get(token);
    const actor = cedula ? buscarPersona(cedula) : null;
    if (!actor) return res.status(401).json({ message: 'Sesión no válida o expirada' });
    if (rolesPermitidos.length && !rolesPermitidos.includes(actor.rol)) {
      return res.status(403).json({ message: 'No tiene permisos para realizar esta operación' });
    }
    req.actor = actor;
    req.sessionToken = token;
    next();
  };
}

function registrarOperacion(tipo, datos) {
  const operacion = {
    id: siguienteOperacionId++,
    tipo,
    fecha: new Date().toISOString(),
    ...datos
  };
  operaciones.push(operacion);
  return operacion;
}

app.get('/api/admin/usuarios', autenticar('administrador'), (req, res) => {
  res.json([...usuarios, ...cajeros, ...administradores]);
});

app.get('/api/admin/clientes', autenticar('administrador'), (req, res) => {
  res.json(usuarios);
});

app.get('/api/admin/cajeros', autenticar('administrador'), (req, res) => {
  res.json(cajeros);
});

app.get('/api/admin/sucursales', autenticar('administrador'), (req, res) => {
  res.json(sucursales);
});

app.get('/api/admin/operaciones', autenticar('administrador'), (req, res) => {
  res.json(operaciones);
});

app.get('/api/cajero/clientes', autenticar('cajero'), (req, res) => {
  res.json(usuarios.map(({ cedula, nombre, saldo, fotoUrl }) => ({ cedula, nombre, saldo, fotoUrl })));
});

app.post('/api/auth/register', (req, res) => {
  const nombre = String(req.body.nombre || '').trim();
  const cedula = String(req.body.cedula || req.body.usuario || '').trim();
  const clave = String(req.body.contrasena || '');

  if (!nombre || !cedula || !clave) {
    return res.status(400).json({ message: 'Nombre, usuario y contraseña son obligatorios' });
  }
  if (clave.length < 10) {
    return res.status(400).json({ message: 'La contraseña debe tener al menos 10 caracteres' });
  }
  if (buscarPersona(cedula)) {
    return res.status(409).json({ message: 'Ya existe una cuenta con esa cédula o usuario' });
  }

  const nuevoUsuario = {
    cedula,
    nombre,
    email: '',
    saldo: 0,
    fotoUrl: '',
    rol: 'cliente'
  };
  usuarios.push(nuevoUsuario);
  guardarClave(cedula, clave);
  res.status(201).json({ message: 'Registro guardado exitosamente', usuario: nuevoUsuario });
});

app.post('/api/auth/login', (req, res) => {
  const identificador = String(req.body.cedula || req.body.usuario || '').trim();
  const clave = String(req.body.contrasena || '');
  const accesoAdministrador = ['admin', 'administrador'].includes(normalizarIdentificador(identificador));
  if (clave.length < 10 && !accesoAdministrador) {
    return res.status(400).json({ message: 'La contraseña debe tener al menos 10 caracteres' });
  }

  const persona = buscarPersona(identificador);
  if (!persona || !validarClave(identificador, clave)) {
    return res.status(401).json({ message: 'Usuario o contraseña incorrectos' });
  }

  const token = crypto.randomBytes(32).toString('hex');
  sesiones.set(token, persona.cedula);
  res.json({ usuario: persona, token });
});

app.post('/api/auth/logout', autenticar(), (req, res) => {
  sesiones.delete(req.sessionToken);
  res.status(204).end();
});

app.post('/api/admin/cajeros', autenticar('administrador'), (req, res) => {
  const cedula = String(req.body.cedula || req.body.usuario || '').trim();
  const nombre = String(req.body.nombre || '').trim();
  const clave = String(req.body.contrasena || '');
  if (!cedula || !nombre || clave.length < 10) {
    return res.status(400).json({ message: 'Indique nombre, usuario y una contraseña de al menos 10 caracteres' });
  }
  if (buscarPersona(cedula)) return res.status(409).json({ message: 'Ya existe una cuenta con ese usuario' });
  const cajero = { cedula, nombre, email: '', saldo: 0, fotoUrl: '', rol: 'cajero', sucursal: req.body.sucursal || '' };
  cajeros.push(cajero);
  guardarClave(cedula, clave);
  res.status(201).json(cajero);
});

app.delete('/api/admin/usuarios/:cedula', autenticar('administrador'), (req, res) => {
  const usuario = usuarios.find((item) => item.cedula === req.params.cedula);
  const cajero = cajeros.find((item) => item.cedula === req.params.cedula);
  if (!usuario && !cajero) return res.status(404).json({ message: 'Usuario no encontrado' });
  if (usuario) usuarios = usuarios.filter((item) => item.cedula !== req.params.cedula);
  if (cajero) cajeros.splice(cajeros.indexOf(cajero), 1);
  credenciales.delete(normalizarIdentificador(req.params.cedula));
  res.status(204).end();
});

app.patch('/api/admin/usuarios/:cedula/saldo', autenticar('administrador'), (req, res) => {
  const usuario = [...usuarios, ...cajeros].find((item) => item.cedula === req.params.cedula);
  const saldo = Math.round(Number(req.body.saldo) * 100) / 100;
  if (!usuario) return res.status(404).json({ message: 'Usuario no encontrado' });
  if (!Number.isFinite(saldo) || saldo < 0) {
    return res.status(400).json({ message: 'El saldo debe ser un monto válido mayor o igual a cero' });
  }
  const saldoAnterior = usuario.saldo;
  usuario.saldo = saldo;
  registrarOperacion('ajuste_administrativo', {
    actor: req.actor.cedula,
    usuario: usuario.cedula,
    saldoAnterior,
    saldoNuevo: saldo
  });
  res.json(usuario);
});

app.post('/api/cajero/depositos', autenticar('cajero'), (req, res) => {
  const usuario = usuarios.find((item) => item.cedula === req.body.cedula);
  const monto = Math.round(Number(req.body.monto) * 100) / 100;
  if (!usuario) return res.status(404).json({ message: 'Cliente no encontrado' });
  if (!Number.isFinite(monto) || monto <= 0) {
    return res.status(400).json({ message: 'Ingrese un monto de depósito válido' });
  }
  usuario.saldo = Math.round((usuario.saldo + monto) * 100) / 100;
  const operacion = registrarOperacion('deposito', {
    actor: req.actor.cedula,
    usuario: usuario.cedula,
    monto
  });
  notificaciones.push({
    id: siguienteNotificacionId++,
    cedula: usuario.cedula,
    titulo: 'Depósito recibido',
    cuerpo: `Has recibido un depósito de $${monto.toFixed(2)} de ${req.actor.nombre}`
  });
  res.status(201).json({ operacion, saldo: usuario.saldo });
});

app.get('/api/cliente/:cedula/amigos', autenticar('cliente'), (req, res) => {
  if (req.actor.cedula !== req.params.cedula) {
    return res.status(403).json({ message: 'Solo puede consultar su propia lista de amigos' });
  }
  const cliente = usuarios.find((usuario) => usuario.cedula === req.params.cedula);
  if (!cliente) return res.status(404).json({ message: 'Cliente no encontrado' });
  res.json(usuarios.filter((usuario) => usuario.cedula !== cliente.cedula));
});

app.get('/api/cliente/puntos-atencion', autenticar('cliente'), (req, res) => {
  res.json({ cajeros, sucursales });
});

app.get('/api/cliente/:cedula', autenticar('cliente', 'administrador'), (req, res) => {
  if (req.actor.rol !== 'administrador' && req.actor.cedula !== req.params.cedula) {
    return res.status(403).json({ message: 'Solo puede consultar su propio perfil' });
  }
  const cliente = usuarios.find(u => u.cedula === req.params.cedula);
  if (cliente) {
    res.json(cliente);
  } else {
    res.status(404).json({ message: "Cliente no encontrado" });
  }
});

app.put('/api/cliente/:cedula', autenticar('cliente'), (req, res) => {
  if (req.actor.cedula !== req.params.cedula) {
    return res.status(403).json({ message: 'Solo puede actualizar su propio perfil' });
  }
  const cliente = usuarios.find((usuario) => usuario.cedula === req.params.cedula);
  if (!cliente) return res.status(404).json({ message: 'Cliente no encontrado' });
  if (typeof req.body.nombre === 'string' && req.body.nombre.trim()) {
    cliente.nombre = req.body.nombre.trim();
  }
  res.json(cliente);
});

app.post('/api/perfil/upload', autenticar('cliente'), upload.single('imagen'), (req, res) => {
  if (req.body.cedula !== req.actor.cedula) {
    return res.status(403).json({ message: 'Solo puede actualizar su propia foto' });
  }
  if (!req.file) {
    return res.status(400).json({ message: "No se subió ninguna imagen" });
  }
  const imageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
  const cliente = usuarios.find((usuario) => usuario.cedula === req.body.cedula);
  if (cliente) cliente.fotoUrl = imageUrl;
  res.json({ message: "Foto actualizada con éxito", url: imageUrl });
});

app.post('/api/transferencias', autenticar('cliente'), (req, res) => {
  if (req.actor.cedula !== req.body.remitente) {
    return res.status(403).json({ message: 'Solo puede enviar transferencias desde su propia cuenta' });
  }
  const remitente = usuarios.find((usuario) => usuario.cedula === req.body.remitente);
  const destinatario = usuarios.find((usuario) => usuario.cedula === req.body.destinatario);
  const monto = Math.round(Number(req.body.monto) * 100) / 100;

  if (!remitente || !destinatario) {
    return res.status(404).json({ message: 'No se encontró el remitente o el destinatario' });
  }
  if (remitente.cedula === destinatario.cedula || !Number.isFinite(monto) || monto <= 0) {
    return res.status(400).json({ message: 'Indique un amigo y un monto válido' });
  }
  if (remitente.saldo < monto) {
    return res.status(400).json({ message: 'Saldo insuficiente para realizar la transferencia' });
  }

  remitente.saldo = Math.round((remitente.saldo - monto) * 100) / 100;
  destinatario.saldo = Math.round((destinatario.saldo + monto) * 100) / 100;
  const transferencia = {
    id: siguienteTransferenciaId++,
    remitente: remitente.cedula,
    destinatario: destinatario.cedula,
    monto,
    fecha: new Date().toISOString()
  };
  transferencias.push(transferencia);
  registrarOperacion('transferencia', {
    actor: remitente.cedula,
    remitente: remitente.cedula,
    destinatario: destinatario.cedula,
    monto
  });
  notificaciones.push({
    id: siguienteNotificacionId++,
    cedula: destinatario.cedula,
    titulo: 'Transferencia recibida',
    cuerpo: `¡Has recibido una transferencia de $${monto.toFixed(2)} de ${remitente.nombre}!`
  });

  res.status(201).json({
    transferencia,
    saldo: remitente.saldo,
    notificacionEmisor: {
      titulo: 'Transferencia realizada con éxito',
      cuerpo: `Transferencia realizada con éxito: Enviaste $${monto.toFixed(2)} a ${destinatario.nombre}`
    }
  });
});

app.get('/api/transferencias/:cedula', autenticar('cliente'), (req, res) => {
  if (req.actor.cedula !== req.params.cedula) {
    return res.status(403).json({ message: 'Solo puede consultar sus propias operaciones' });
  }
  const historial = transferencias.filter(
    (transferencia) => transferencia.remitente === req.params.cedula ||
      transferencia.destinatario === req.params.cedula
  );
  res.json(historial);
});

app.get('/api/notificaciones/:cedula', autenticar('cliente'), (req, res) => {
  if (req.actor.cedula !== req.params.cedula) {
    return res.status(403).json({ message: 'Solo puede consultar sus propias notificaciones' });
  }
  const pendientes = notificaciones.filter((notificacion) => notificacion.cedula === req.params.cedula);
  notificaciones = notificaciones.filter((notificacion) => notificacion.cedula !== req.params.cedula);
  res.json(pendientes);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor backend corriendo en http://localhost:${PORT}`);
});
