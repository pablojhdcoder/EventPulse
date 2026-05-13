# Seeds para demo y desarrollo local.
# Se ejecutan con: mix ecto.setup
#
# Deja exactamente 3 eventos de ejemplo (cualquier otro evento en BD se elimina).

import Ecto.Query

alias EventPulse.Repo
alias EventPulse.Events
alias EventPulse.Events.Event
alias EventPulse.Accounts.User
alias EventPulse.Votes
alias EventPulse.Votes.Poll
alias EventPulse.Votes.Vote
alias EventPulse.SocialFeeling.Result

now = DateTime.utc_now() |> DateTime.truncate(:second)

# Social feeling no tiene FK a events en migraciones: borrar antes que events.
# Polls tienen ON DELETE CASCADE desde events; votes desde polls.
Repo.delete_all(Result)
Repo.delete_all(Event)

# Debe cumplir las reglas de User.changeset (longitud y complejidad).
password = "Admin!1demo"

directo_options = ["1", "2", "3"]

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

ensure_poll = fn event, question, options ->
  case Repo.one(
         from p in Poll, where: p.event_id == ^event.id and p.question == ^question, limit: 1
       ) do
    %Poll{} = p ->
      p

    nil ->
      {:ok, poll} = Votes.create_poll(event.id, question, options)
      poll
  end
end

insert_vote_once = fn attrs ->
  %Vote{}
  |> Vote.changeset(attrs)
  |> Repo.insert!(
    on_conflict: [set: [choice: attrs.choice]],
    conflict_target: [:user_id, :poll_id]
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

{:ok, event_programado} =
  Events.create_event(%{
    title: "test evento programado",
    description: "Evento de ejemplo en estado programado.",
    category: "tecnologia",
    status: "programado",
    starts_at: DateTime.add(now, 7 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 7 * 24 * 3600 + 7200, :second)
  })

{:ok, event_directo} =
  Events.create_event(%{
    title: "test evento en directo",
    description: "evento live",
    category: "musica",
    status: "en_directo",
    starts_at: DateTime.add(now, -3600, :second),
    ends_at: DateTime.add(now, 3600, :second)
  })

{:ok, event_finalizado} =
  Events.create_event(%{
    title: "Test evento finalizado",
    description: "Evento ya finalizado",
    category: "deportes",
    status: "finalizado",
    starts_at: DateTime.add(now, -14 * 24 * 3600, :second),
    ends_at: DateTime.add(now, -14 * 24 * 3600 + 7200, :second)
  })

_ = ensure_poll.(event_programado, "Votación demo", directo_options)

poll_directo =
  ensure_poll.(event_directo, "Votación en directo", directo_options)

poll_finalizado =
  ensure_poll.(
    event_finalizado,
    "Valoración del evento",
    ["1", "2", "3", "4"]
  )

insert_vote_once.(%{
  poll_id: poll_directo.id,
  user_id: 1,
  choice: "1"
})

insert_vote_once.(%{
  poll_id: poll_directo.id,
  user_id: 2,
  choice: "2"
})

insert_vote_once.(%{
  poll_id: poll_finalizado.id,
  user_id: 1,
  choice: "4"
})

IO.puts("""
Seeds cargados (solo 3 eventos):
  Usuarios (UUID): demo_admin / demo_participant — contraseña: #{password}
  — "#{event_programado.title}" (programado) id=#{event_programado.id}
  — "#{event_directo.title}" (en_directo) id=#{event_directo.id}
  — "#{event_finalizado.title}" (finalizado) id=#{event_finalizado.id}
  Polls y votos de ejemplo alineados con la UI numérica.
""")
