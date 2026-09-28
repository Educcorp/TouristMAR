// Copia a apps/mobile los assets que declara apps/web y avisa si el pubspec
// del móvil no declara los mismos. Uso: node scripts/sync-mobile-assets.js
const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const webDir = path.join(root, 'apps', 'web')
const mobileDir = path.join(root, 'apps', 'mobile')

function declaredAssets(pubspecPath) {
  const text = fs.readFileSync(pubspecPath, 'utf8')
  const block = text.split(/^\s*assets:\s*$/m)[1] || ''
  const assets = []
  for (const line of block.split(/\r?\n/)) {
    if (line.trim() === '' && assets.length === 0) continue
    const match = line.match(/^\s+-\s+(\S+)\s*$/)
    if (!match) break
    assets.push(match[1])
  }
  return assets
}

const webAssets = declaredAssets(path.join(webDir, 'pubspec.yaml'))
const mobileAssets = new Set(declaredAssets(path.join(mobileDir, 'pubspec.yaml')))

for (const asset of webAssets) {
  const target = path.join(mobileDir, asset)
  fs.mkdirSync(path.dirname(target), { recursive: true })
  fs.copyFileSync(path.join(webDir, asset), target)
}
console.log(`Copiados ${webAssets.length} assets de apps/web a apps/mobile.`)

const missing = webAssets.filter((asset) => !mobileAssets.has(asset))
if (missing.length > 0) {
  console.error('Faltan en apps/mobile/pubspec.yaml (sección flutter > assets):')
  for (const asset of missing) console.error(`  - ${asset}`)
  process.exit(1)
}
