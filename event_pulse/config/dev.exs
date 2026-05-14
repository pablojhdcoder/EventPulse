import Config

# Base de datos
config :event_pulse, EventPulse.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_pulse_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Desarrollo: sin caché de código, recarga y depuración activas.
#
# La opción `watchers` permite ejecutar procesos externos (p. ej. bundlers)
# junto al servidor para compilar `.js` y `.css`.
config :event_pulse, EventPulseWeb.Endpoint,
  # Enlazar solo a loopback (IPv4) evita acceso desde otras máquinas.
  # Usa `ip: {0, 0, 0, 0}` si quieres permitir acceso en red local.
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dSM/y3X1v28tnJBi2tuU2zlTeHkvAcCDFUA8U1BvcRB5tVPJUa6ZMpfMmJHVf8er",
  watchers: []

# ## Soporte SSL
#
# Para HTTPS en desarrollo puedes generar un certificado autofirmado con:
#
#     mix phx.gen.cert
#
# Consulta `mix help phx.gen.cert` para más detalle.
#
# Sustituye la clave `http:` anterior por algo como:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# También puedes definir `http:` y `https:` a la vez en puertos distintos.

# Rutas de desarrollo (LiveDashboard, buzón de correo)
config :event_pulse, dev_routes: true

# Logs de desarrollo sin metadatos extra
config :logger, :default_formatter, format: "[$level] $message\n"

# Profundidad de trazas en desarrollo (en producción un valor alto puede ser costoso)
config :phoenix, :stacktrace_depth, 20

# Inicializar plugs en tiempo de ejecución para compilar más rápido en desarrollo
config :phoenix, :plug_init_mode, :runtime

# Swoosh: sin cliente HTTP (solo hace falta en adaptadores de producción)
config :swoosh, :api_client, false
