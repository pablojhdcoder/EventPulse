# Seeds para demo y desarrollo local.
# Se ejecutan con: mix ecto.setup

alias EventPulse.Repo
alias EventPulse.Events
alias EventPulse.Accounts.User
alias EventPulse.Votes.Vote

now = DateTime.utc_now() |> DateTime.truncate(:second)

# Debe cumplir las reglas de User.changeset (longitud y complejidad).
password = "Admin!1demo"

create_user_once = fn attrs ->
  case Repo.get_by(User, email: attrs.email) do
    nil ->
      %User{id: Ecto.UUID.generate()}
      |> User.changeset(attrs)
      |> Repo.insert!()

    user ->
      user
  end
end

create_event_once = fn attrs ->
  case EventPulse.Events.Event |> Repo.get_by(title: attrs.title) do
    nil ->
      {:ok, event} = Events.create_event(attrs)
      event

    event ->
      event
  end
end

insert_vote_once = fn attrs ->
  %Vote{}
  |> Vote.changeset(attrs)
  |> Repo.insert!(
    on_conflict: [set: [choice: attrs.choice]],
    conflict_target: [:user_id, :event_id]
  )
end

_admin =
  create_user_once.(%{
    username: "demo_admin",
    email: "admin@demo.eventpulse",
    password: password,
    role: "admin"
  })

_participant =
  create_user_once.(%{
    username: "demo_participant",
    email: "participant@demo.eventpulse",
    password: password,
    role: "participant"
  })

event_programado =
  create_event_once.(%{
    title: "Presentacion AS",
    description: "Evento de ejemplo en estado programado.",
    category: "tecnologia",
    status: "programado",
    starts_at: DateTime.add(now, 7 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 7 * 24 * 3600 + 7200, :second)
  })

event_directo =
  create_event_once.(%{
    title: "Streaming en vivo",
    description: "Sala de chat activa para pruebas con WebSocket.",
    category: "musica",
    status: "en_directo",
    starts_at: DateTime.add(now, -3600, :second),
    ends_at: DateTime.add(now, 3600, :second)
  })

event_finalizado =
  create_event_once.(%{
    title: "Concierto",
    description: "Evento cerrado con historial y votación de ejemplo.",
    category: "musica",
    status: "finalizado",
    starts_at: DateTime.add(now, -14 * 24 * 3600, :second),
    ends_at: DateTime.add(now, -14 * 24 * 3600 + 7200, :second)
  })

insert_vote_once.(%{
  event_id: event_directo.id,
  user_id: 1,
  choice: "opcion_a"
})

insert_vote_once.(%{
  event_id: event_directo.id,
  user_id: 2,
  choice: "opcion_b"
})

insert_vote_once.(%{
  event_id: event_finalizado.id,
  user_id: 1,
  choice: "muy_bueno"
})

IO.puts("""
Seeds cargados:
  Usuarios (UUID): demo_admin / demo_participant — contraseña: #{password}
  Eventos: id=#{event_programado.id} programado, id=#{event_directo.id} en_directo, id=#{event_finalizado.id} finalizado
  Votos de ejemplo en eventos en_directo y finalizado.
""")
