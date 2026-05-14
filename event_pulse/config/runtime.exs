import Config

# `config/runtime.exs` se ejecuta en todos los entornos, también en releases.
# Corre tras la compilación y antes de arrancar el sistema: sirve para cargar
# configuración de producción y secretos desde variables de entorno. No definas
# aquí opciones solo de compilación: no se aplicarán.
# El bloque siguiente concentra la configuración de runtime en producción.

# ## Uso de releases
#
# Con `mix release` hay que habilitar explícitamente el servidor HTTP con
# `PHX_SERVER=true` al arrancar:
#
#     PHX_SERVER=true bin/event_pulse start
#
# Alternativamente, `mix phx.gen.release` puede generar un script `bin/server`
# que fija esa variable automáticamente.
if System.get_env("PHX_SERVER") do
  config :event_pulse, EventPulseWeb.Endpoint, server: true
end

config :event_pulse, EventPulseWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

config :event_pulse, :redis_url, System.get_env("REDIS_URL", "redis://localhost:6379/0")

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      falta la variable de entorno DATABASE_URL.
      Ejemplo: ecto://USUARIO:CLAVE@HOST/BASE_DE_DATOS
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :event_pulse, EventPulse.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # En máquinas con muchos núcleos puedes valorar varios pools (`pool_count`).
    # pool_count: 4,
    socket_options: maybe_ipv6

  # `secret_key_base` firma cookies y otros secretos. En dev/test hay valores por
  # defecto; en producción usa otro y no lo subas al repositorio: típicamente
  # variable de entorno.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      falta la variable de entorno SECRET_KEY_BASE.
      Genera un valor con: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :event_pulse, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :event_pulse, EventPulseWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # IPv6 en todas las interfaces. Usa `{0, 0, 0, 0, 0, 0, 0, 1}` solo para acceso local.
      # Documentación: https://hexdocs.pm/bandit/Bandit.html#t:options/0
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL (HTTPS)
  #
  # Para HTTPS añade la clave `https` al endpoint, por ejemplo:
  #
  #     config :event_pulse, EventPulseWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("RUTA_CLAVE_SSL"),
  #         certfile: System.get_env("RUTA_CERT_SSL")
  #       ]
  #
  # `cipher_suite: :strong` limita a cifras modernas (navegadores antiguos pueden fallar).
  # Usa `:compatible` si necesitas soporte más amplio.
  #
  # `keyfile` y `certfile` suelen ser rutas absolutas o relativas dentro de `priv/`,
  # p. ej. `priv/ssl/server.key`. Opciones completas: https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # Conviene activar `force_ssl` en `config/prod.exs` para forzar HTTPS.
  #
  # Más opciones en la documentación de `Plug.SSL` y `force_ssl`.

  # ## Correo en producción
  #
  # Configura otro adaptador de Swoosh. Ejemplo Mailgun:
  #
  #     config :event_pulse, EventPulse.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Muchos adaptadores no SMTP requieren cliente HTTP. Swoosh admite Req, Hackney
  # y Finch; a menudo se fija en tiempo de compilación en `config/prod.exs`:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # https://hexdocs.pm/swoosh/Swoosh.html#module-installation

  if System.get_env("DOCKER_DEMO") in ~w(true 1) do
    port = String.to_integer(System.get_env("PORT") || "4000")
    public_host = System.get_env("PHX_PUBLIC_HOST") || "localhost"
    public_port = String.to_integer(System.get_env("PHX_PUBLIC_PORT") || "8080")

    config :event_pulse, EventPulseWeb.Endpoint,
      url: [host: public_host, port: public_port, scheme: "http"],
      http: [ip: {0, 0, 0, 0}, port: port],
      check_origin: [
        "//#{public_host}:#{public_port}",
        "http://#{public_host}:#{public_port}"
      ]
  end
end
