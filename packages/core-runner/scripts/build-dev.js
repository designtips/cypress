var z = require('zunder')
var u = z.undertaker
var setZunderConfig = require('./set-zunder-config')

setZunderConfig(z)

foo.bar()

u.series(
  z.applyDevEnv,
  z.cleanDev,
  z.buildDevScripts,
  z.buildDevStylesheets,
  z.buildDevStaticAssets
)()
