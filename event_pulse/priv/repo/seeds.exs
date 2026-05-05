# Seeds para demo y desarrollo local.
# Se ejecutan con: mix ecto.setup

alias EventPulse.Repo
alias EventPulse.Events
alias EventPulse.Accounts.User
alias EventPulse.Votes.Vote

now = DateTime.utc_now() |> DateTime.truncate(:second)

# Debe cumplir las reglas de User.changeset (longitud y complejidad).
password = "Admin!1demo"

admin_id = Ecto.UUID.generate()
participant_id = Ecto.UUID.generate()

%User{id: admin_id}
|> User.changeset(%{
  username: "demo_admin",
  email: "admin@demo.eventpulse",
  password: password,
  role: "admin"
})
|> Repo.insert!()

%User{id: participant_id}
|> User.changeset(%{
  username: "demo_participant",
  email: "participant@demo.eventpulse",
  password: password,
  role: "participant"
})
|> Repo.insert!()

{:ok, event_programado} =
  Events.create_event(%{
    title: "Presentacion AS",
    description: "Evento de ejemplo en estado programado.",
    category: "tecnologia",
    status: "programado",
    starts_at: DateTime.add(now, 7 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 7 * 24 * 3600 + 7200, :second)
  })

{:ok, event_directo} =
  Events.create_event(%{
    title: "Streaming en vivo",
    description: "Sala de chat activa para pruebas con WebSocket.",
    category: "musica",
    status: "en_directo",
    starts_at: DateTime.add(now, -3600, :second),
    ends_at: DateTime.add(now, 3600, :second)
  })

{:ok, event_finalizado} =
  Events.create_event(%{
    title: "Concierto",
    description: "Evento cerrado con historial y votación de ejemplo.",
    category: "musica",
    status: "finalizado",
    starts_at: DateTime.add(now, -14 * 24 * 3600, :second),
    ends_at: DateTime.add(now, -14 * 24 * 3600 + 7200, :second)
  })

%Vote{}
|> Vote.changeset(%{
  event_id: event_directo.id,
  user_id: 1,
  choice: "opcion_a"
})
|> Repo.insert!()

%Vote{}
|> Vote.changeset(%{
  event_id: event_directo.id,
  user_id: 2,
  choice: "opcion_b"
})
|> Repo.insert!()

%Vote{}
|> Vote.changeset(%{
  event_id: event_finalizado.id,
  user_id: 1,
  choice: "muy_bueno"
})
|> Repo.insert!()

IO.puts("""
Seeds cargados:
  Usuarios (UUID): demo_admin / demo_participant — contraseña: #{password}
  Eventos: id=#{event_programado.id} programado, id=#{event_directo.id} en_directo, id=#{event_finalizado.id} finalizado
  Votos de ejemplo en eventos en_directo y finalizado.
""")
