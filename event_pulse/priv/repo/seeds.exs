# Seeds para demo y desarrollo local.
# Se ejecutan con: mix ecto.setup

import Ecto.Query

alias EventPulse.Repo
alias EventPulse.Events
alias EventPulse.Events.Event
alias EventPulse.Accounts.User
alias EventPulse.Votes
alias EventPulse.Votes.Poll
alias EventPulse.Votes.Vote

now = DateTime.utc_now() |> DateTime.truncate(:second)

# Polls tienen ON DELETE CASCADE desde events; votes desde polls.
Repo.delete_all(Event)

# Debe cumplir las reglas de User.changeset (longitud y complejidad).
password = "Admin!1demo"

directo_options = ["1", "2", "3"]

create_user_once = fn attrs ->
  existing =
    Repo.one(
      from u in User,
        where: u.email == ^attrs.email or u.username == ^attrs.username,
        limit: 1
    )

  case existing do
    nil ->
      %User{id: Ecto.UUID.generate()}
      |> User.changeset(attrs)
      |> Repo.insert!()

    %User{} = user ->
      user
      |> User.changeset(attrs)
      |> Repo.update!()
  end
end

ensure_poll = fn event, question, options ->
  case Repo.one(
         from p in Poll, where: p.event_id == ^event.id and p.question == ^question, limit: 1
       ) do
    %Poll{} = p ->
      p

    nil ->
      case Votes.create_poll(event.id, question, options) do
        {:ok, poll} ->
          poll

        {:error, changeset} ->
          raise "seed: create_poll falló (#{question}): #{inspect(changeset.errors)}"
      end
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
    email: "admin@eventpulse.local",
    password: password,
    role: "admin"
  })

_participant =
  create_user_once.(%{
    username: "demo_participant",
    email: "participant@eventpulse.local",
    password: password,
    role: "participant"
  })

_ =
  create_user_once.(%{
    username: "paco",
    email: "paco@eventpulse.local",
    password: password,
    role: "participant"
  })

_ =
  create_user_once.(%{
    username: "manolo",
    email: "manolo@eventpulse.local",
    password: password,
    role: "participant"
  })

# Futuro: keynote iPhone 18
{:ok, event_programado} =
  Events.create_event(%{
    title: "Apple — Presentación iPhone 18",
    description: "Se esperan nuevos materiales, supuesto chip A20 y la gama Pro",
    category: "tecnologia",
    status: "programado",
    starts_at: DateTime.add(now, 21 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 21 * 24 * 3600 + 2 * 3600, :second)
  })

# En directo: presentación del proyecto (EventPulse / práctica)
{:ok, event_directo} =
  Events.create_event(%{
    title: "EventPulse — Presentación del proyecto",
    description: "Demo en vivo",
    category: "tecnologia",
    status: "en_directo",
    starts_at: DateTime.add(now, -3600, :second),
    ends_at: DateTime.add(now, 3600, :second)
  })

# Pasado: clásico fin de semana (10–11 mayo 2026)
{:ok, event_finalizado} =
  Events.create_event(%{
    title: "LaLiga — FC Barcelona vs Real Madrid",
    description: "El gran clásico de LaLiga",
    category: "deportes",
    status: "finalizado",
    starts_at: ~U[2026-05-10 18:30:00Z],
    ends_at: ~U[2026-05-10 20:45:00Z]
  })

# Encuestas del evento en directo: numéricas (legado) y de texto
poll_directo_bloque =
  ensure_poll.(
    event_directo,
    "¿Qué bloque de la demo te interesa más?",
    ["Phoenix/LiveView", "Docker/Compose", "Cluster/OTP"]
  )

poll_directo =
  ensure_poll.(
    event_directo,
    "Mini-encuesta: estado de ánimo (1 = bajo, 3 = arriba)",
    directo_options
  )

poll_directo_sesion =
  ensure_poll.(
    event_directo,
    "¿Cómo valoras la sesión hasta ahora?",
    ["Muy bien", "Bien", "Regular", "Mal"]
  )

# Encuestas del evento finalizado: texto y numérica (legado)
poll_finalizado_jugador =
  ensure_poll.(
    event_finalizado,
    "¿Cuál fue el mejor jugador del clásico?",
    ["Rashford", "Ferran Torres", "Vinicius Jr", "Pedri"]
  )

poll_finalizado_valoracion =
  ensure_poll.(
    event_finalizado,
    "Valora el partido del 1 al 3",
    ["1", "2", "3"]
  )

# Votos demo: user_id entero anónimo en UI (no UUID de cuentas).
insert_vote_once.(%{poll_id: poll_directo.id, user_id: 1, choice: "1"})
insert_vote_once.(%{poll_id: poll_directo.id, user_id: 2, choice: "2"})
insert_vote_once.(%{poll_id: poll_directo.id, user_id: 3, choice: "3"})
insert_vote_once.(%{poll_id: poll_directo.id, user_id: 4, choice: "1"})

insert_vote_once.(%{poll_id: poll_directo_bloque.id, user_id: 1, choice: "Phoenix/LiveView"})
insert_vote_once.(%{poll_id: poll_directo_bloque.id, user_id: 2, choice: "Docker/Compose"})
insert_vote_once.(%{poll_id: poll_directo_bloque.id, user_id: 6, choice: "Cluster/OTP"})

insert_vote_once.(%{poll_id: poll_directo_sesion.id, user_id: 1, choice: "Muy bien"})
insert_vote_once.(%{poll_id: poll_directo_sesion.id, user_id: 2, choice: "Bien"})
insert_vote_once.(%{poll_id: poll_directo_sesion.id, user_id: 8, choice: "Muy bien"})

insert_vote_once.(%{poll_id: poll_finalizado_jugador.id, user_id: 1, choice: "Pedri"})
insert_vote_once.(%{poll_id: poll_finalizado_jugador.id, user_id: 6, choice: "Vinicius Jr"})
insert_vote_once.(%{poll_id: poll_finalizado_jugador.id, user_id: 7, choice: "Pedri"})

insert_vote_once.(%{poll_id: poll_finalizado_valoracion.id, user_id: 1, choice: "3"})
insert_vote_once.(%{poll_id: poll_finalizado_valoracion.id, user_id: 6, choice: "2"})

IO.puts("""
Seeds cargados (3 eventos):
  Contraseña: #{password}
  Cuentas (login por email):
    admin@eventpulse.local (admin)
    participant@eventpulse.local, paco@eventpulse.local, manolo@eventpulse.local (participantes)
  — Futuro (sin encuestas): "#{event_programado.title}" id=#{event_programado.id}
  — En directo (encuestas texto + numérica): "#{event_directo.title}" id=#{event_directo.id}
  — Pasado (encuestas texto + numérica): "#{event_finalizado.title}" id=#{event_finalizado.id}
  Votos de ejemplo: user_id 1–8 (anónimos respecto a UUID de usuarios).
""")
