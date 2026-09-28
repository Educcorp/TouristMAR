// Corre la app móvil (apps/mobile) apuntando al backend de esta PC.
//
// En el celular "localhost" es el propio teléfono, así que la app necesita la
// IP de la PC en la red local para llegar a la API (login, y la URL que se le
// pasa a Unity para GET /api/marcadores). Este script la detecta y la pasa
// como --dart-define=API_URL. Uso (desde la raíz, con el backend corriendo):
//
//   npm run dev:mobile                 → detecta la IP
//   npm run dev:mobile -- -d <device>  → argumentos extra para `flutter run`
//   API_URL=https://mi-dominio/api npm run dev:mobile   → otra API (p. ej. producción)
//
// El celular y la PC tienen que estar en la misma red Wi-Fi.
const os = require('os')
const path = require('path')
const { spawn } = require('child_process')

// Interfaces virtuales (Docker, VMs, VPNs) no son alcanzables desde el celular.
const VIRTUALES = /^(docker|br-|virbr|veth|vmnet|vboxnet|tun|tap|utun|lo)/

function ipLocal() {
  const candidatas = []
  for (const [nombre, direcciones] of Object.entries(os.networkInterfaces())) {
    if (VIRTUALES.test(nombre)) continue
    for (const d of direcciones ?? []) {
      if (d.family === 'IPv4' && !d.internal) candidatas.push({ nombre, ip: d.address })
    }
  }
  // Wi-Fi/Ethernet primero (wlan*, wlp*, eth*, enp*, en0…).
  candidatas.sort((a, b) => Number(/^(wl|en|eth)/.test(b.nombre)) - Number(/^(wl|en|eth)/.test(a.nombre)))
  return candidatas[0]
}

let apiUrl = process.env.API_URL
if (!apiUrl) {
  const local = ipLocal()
  if (!local) {
    console.error('No se encontró una IP de red local. Conéctate al Wi-Fi o pasa API_URL=http://<IP>:4000/api')
    process.exit(1)
  }
  apiUrl = `http://${local.ip}:4000/api`
  console.log(`Usando la IP de ${local.nombre}: ${local.ip}`)
}
console.log(`API_URL=${apiUrl}`)
console.log(`Prueba desde el navegador del celular: ${apiUrl}/marcadores`)

const args = ['run', `--dart-define=API_URL=${apiUrl}`, ...process.argv.slice(2)]
const flutter = spawn('flutter', args, {
  cwd: path.join(__dirname, '..', 'apps', 'mobile'),
  stdio: 'inherit',
  shell: process.platform === 'win32',
})
flutter.on('exit', (code) => process.exit(code ?? 0))
