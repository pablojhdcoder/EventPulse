# Registro de decisiones de arquitectura (ADR) — EventPulse

Los **ADR** (*Architecture Decision Records*) documentan decisiones relevantes del proyecto: contexto, opción elegida e impacto. Complementan `propuesta.md` y `arquitectura.md`.

---

## ADR-001: Producto EventPulse frente a ideas previas de planificación

**Estado:** Aceptado.

**Contexto:** En la planificación inicial se valoraron otras líneas de producto (por ejemplo una herramienta colaborativa tipo gestión de tareas). La asignatura pedía un reto de diseño alineado con arquitectura software y el temario (concurrencia, distribución, tolerancia a fallos).

**Decisión:** Centrar el trabajo en **EventPulse**: eventos en vivo con estados (`programado`, `en_directo`, `finalizado`), participación mediante interfaz web, chat en tiempo real y votaciones por encuestas (`polls`), con autenticación de usuarios y roles (participante / administrador).

**Consecuencias:** El alcance queda acotado a dominio “evento + sala + votación + cierre”. Cualquier documento histórico de ideas descartadas queda fuera del código productivo; la propuesta formal sigue en `propuesta.md` como referencia de requisitos, admitiendo divergencias puntuales con la implementación.

---

## ADR-002: Interfaz y tiempo real con Phoenix LiveView

**Estado:** Aceptado.

**Contexto:** Se necesitaba una UI reactiva sin construir un SPA aparte, y canales de difusión para chat y recuentos con baja fricción en **Elixir**.

**Decisión:** Implementar la aplicación con **Phoenix** y **LiveView** (`EventPulseWeb.EventLive.*`), usando **PubSub** para mensajes entre procesos y clientes conectados (tópicos `event:<id>`, `events:<id>`, `events:updates`, `poll:<id>`, etc.).

**Consecuencias:** Menos piezas en frontend; el estado de pantalla vive en procesos LiveView. Hay que diseñar bien suscripciones y `handle_info` para no saturar ni duplicar lógica. Encaja con los RNF de concurrencia y experiencia de chat fluida de la propuesta.

---

## ADR-003: Persistencia relacional en PostgreSQL (Ecto)

**Estado:** Aceptado.

**Contexto:** Usuarios, eventos, encuestas y votos deben sobrevivir a reinicios y ser la referencia en el cierre del evento; hace falta consistencia fuerte para reglas de negocio.

**Decisión:** Usar **PostgreSQL** como almacén autoritativo vía **Ecto** (`EventPulse.Repo`), con migraciones versionadas en `priv/repo/migrations/`. Los votos se persisten con restricciones de un voto por usuario y encuesta (`on_conflict` / claves adecuadas en el esquema).

**Consecuencias:** Toda réplica de aplicación comparte la misma verdad de datos. El rendimiento depende del pool de conexiones y del dimensionamiento de BD. Los despliegues **Docker** usan un job `migrate` antes de levantar las webs para evitar carreras en migraciones.

---

## ADR-004: Redis (Streams) para el buffer reciente del chat

**Estado:** Aceptado.

**Contexto:** Con varias réplicas detrás del balanceador, guardar solo en memoria del nodo haría que el historial reciente del chat dependiera de la réplica a la que cayera el usuario.

**Decisión:** Usar **Redis** con **streams** y longitud acotada (`EventPulse.ChatBuffer`, `MAXLEN`) para los últimos N mensajes por sala; `EventPulse.Chat.EventRoom` escribe en Redis y difunde por PubSub.

**Consecuencias:** Hidratación coherente al entrar en la sala en cualquier nodo. No es archivo histórico completo de chat en PostgreSQL: es estado efímero compartido. Si Redis falla, el cierre del evento en BD no se revierte; la limpieza del buffer al cerrar es best-effort (como documenta `EventPulse.Events`).

---

## ADR-005: Demo distribuida — clúster OTP, PubSub PG2 y agregador único de votos

**Estado:** Aceptado.

**Contexto:** La asignatura pide visibilidad de escalado horizontal y proceso distribuido. Varios nodos **BEAM** implican riesgo de estado duplicado si cada uno mantuviera su propio contador de votos en memoria.

**Decisión:**

- **Docker Compose** con `web1` / `web2` / `web3`, **PostgreSQL**, **Redis** y un director **NGINX** (`nginx:alpine`, no Nginx Proxy Manager) que balancea HTTP y WebSocket (`least_conn`, cabeceras `Upgrade`).
- **libcluster** con `CLUSTER_PEER_HOSTS` para formar clúster Erlang en la demo.
- **Phoenix.PubSub.PG2** para replicar broadcasts entre nodos.
- `EventPulse.Votes.VoteAggregator` registrado como `{:global, …}`: un solo **GenServer** líder en el clúster para el mapa en vivo de votos; persistencia periódica a PostgreSQL. En Compose, `START_VOTE_AGGREGATOR` solo en `web1` (las demás réplicas no arrancan el hijo en el supervisor local); el `start_link` tolera competencia por el nombre global cuando varias réplicas sí intentan registrarlo a la vez.

**Consecuencias:** Los votos en vivo convergen en un proceso; cualquier réplica enruta `cast`/`call` al líder. El agregador es un punto único de proceso para ese estado en memoria (mitigado por supervisión **OTP** y por la BD como respaldo). La observabilidad distribuida debe hacerse con las herramientas acordadas en el equipo (p. ej. RPC sobre nodo vivo, no `eval` aislado), según guías del proyecto.

---

## ADR-006: Cierre del evento y resultados en interfaz (evolución respecto a Social Feeling)

**Estado:** Aceptado (con matices).

**Contexto:** Versiones anteriores de la propuesta contemplaban **Social Feeling** agregado y persistido. La arquitectura vigente en `arquitectura.md` y los RF/RNF actuales en `propuesta.md` indican que, en la implementación actual, en evento finalizado la **LiveView** muestra un recap de votaciones por encuesta leído de base de datos, y que no hay fila dedicada de resultado tipo Social Feeling en PostgreSQL (migraciones posteriores retiraron esa tabla).

**Decisión:** Mantener como fuente de verdad post-cierre los votos y encuestas en PostgreSQL y la UI de recap (`Votes.list_polls_with_db_results` / vista en `EventLive.Show`). No desarrollar en este repositorio un módulo OTP separado “Social Feeling Worker” ni persistir un agregado con nombre homónimo, hasta que se realinee explícitamente la propuesta con el código.

**Consecuencias:** La presentación y la memoria deben **explicitar** esta evolución frente a material antiguo que aún cite **Social Feeling** persistido. Ventaja: menor complejidad y menos riesgo de inconsistencia entre indicador agregado y votos crudos. Deuda posible: si en el futuro se exige el indicador agregado, habrá que reintroducir modelo de datos, cálculo y pruebas, y un ADR nuevo que sustituya o refine este.
