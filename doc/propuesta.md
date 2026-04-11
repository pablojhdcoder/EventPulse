# EventPulse — Propuesta de proyecto

## 1. Descripción general

EventPulse es una plataforma de comunicación en tiempo real que permite a usuarios registrados participar en eventos de la vida real mediante chat en vivo y votaciones mientras el evento está en directo.

Al finalizar el evento, el sistema cierra votaciones y mensajes, agrega los votos y calcula el Social Feeling, un indicador cuantitativo y cualitativo que resume la percepción colectiva. Ese resultado y las votaciones quedan persistidos y consultables en el detalle del evento.

El proyecto aprovecha Elixir/OTP: procesos ligeros, tolerancia a fallos por supervisión y modelo adecuado para mensajería concurrente y distribuida bajo carga.

## 2. Actores

| Actor | Rol |
|--------|-----|
| Participante | Usuario registrado: consulta eventos, entra en salas en directo, chatea y vota. |
| Administrador | Gestiona el ciclo de vida y catálogo de eventos (creación, estados, cierre). |

## 3. Requisitos funcionales

### 3.1 Gestión de usuarios

| ID | Requisito |
|----|-----------|
| RF-01 | El sistema deberá permitir el registro de usuarios con nombre de usuario, correo electrónico y contraseña válidos. |
| RF-02 | El sistema deberá autenticar usuarios mediante credenciales. |

### 3.2 Gestión de eventos

| ID | Requisito |
|----|-----------|
| RF-03 | El sistema deberá permitir a los administradores crear eventos con al menos: nombre, descripción, categoría, fecha/hora de inicio y fecha/hora estimada de fin; asimismo deberá permitir consultar, actualizar y eliminar eventos. |
| RF-04 | Cada evento deberá encontrarse en uno de los estados: programado, en directo o finalizado. |
| RF-05 | El sistema deberá listar eventos en directo y permitir filtrado o búsqueda por categoría según el modelo de datos acordado. |

### 3.3 Chat en tiempo real

| ID | Requisito |
|----|-----------|
| RF-06 | Un usuario autenticado deberá poder unirse a la sala de chat de un evento en directo (y abandonarla de forma ordenada). |
| RF-07 | Los mensajes enviados por un usuario deberán difundirse en tiempo real a todos los participantes conectados a la misma sala. |
| RF-08 | El sistema deberá mantener un buffer de los últimos N mensajes de la sala (orden cronológico) y, al unirse un participante o reconectarse, enviarle esos mensajes para que recupere el contexto reciente de la conversación. |

### 3.4 Votaciones

| ID | Requisito |
|----|-----------|
| RF-09 | Cada evento deberá poder tener una o más preguntas de votación asociadas. |
| RF-10 | Un usuario deberá poder emitir o modificar su voto mientras la votación o el evento no hayan terminado. |
| RF-11 | Los resultados parciales deberán actualizarse y difundirse a los participantes en tiempo razonablemente cercano al real. |

### 3.5 Cierre, Social Feeling e historial

| ID | Requisito |
|----|-----------|
| RF-12 | Al finalizar el evento, las votaciones deberán cerrarse y el sistema deberá calcular el Social Feeling (sin aceptar votos posteriores al cierre). |
| RF-13 | El sistema deberá computar el Social Feeling como agregación ponderada de todas las votaciones recibidas (o fórmula equivalente fijada y documentada). |
| RF-14 | El Social Feeling y el historial completo de votaciones deberán persistirse de forma permanente y ser accesibles en el detalle del evento vía API (y/o contrato documentado). |

## 4. Requisitos no funcionales

| ID | Atributo de calidad | Requisito |
|----|---------------------|-----------|
| RNF-01 | Escalabilidad / concurrencia | El diseño deberá permitir crecer en número de conexiones concurrentes de forma razonable. |
| RNF-02 | Rendimiento (chat) | El chat deberá sentirse fluido: la propagación de mensajes a los participantes de una sala será un objetivo de baja latencia. |
| RNF-03 | Disponibilidad | El diseño deberá favorecer la continuidad del servicio (réplicas, supervisión OTP, recuperación ante fallos de proceso). |
| RNF-04 | Tolerancia a fallos | Se buscará que el fallo de una sala o proceso aislable tenga impacto acotado en el resto del sistema y que los supervisores OTP permitan recuperación automática o manual. |
| RNF-05 | Consistencia de votos | A efectos de cierre del evento, deberá garantizarse un solo voto vigente por usuario y pregunta; los recuentos en vivo en un despliegue multi‑nodo podrán mostrar pequeños desfases breves entre clientes. |
| RNF-06 | Escalabilidad horizontal | La arquitectura deberá contemplar varios nodos de aplicación y el reparto de carga a alto nivel. |
| RNF-07 | Seguridad | Las contraseñas no se almacenarán en claro; se usará un hash fuerte de uso habitual en Elixir (p. ej. bcrypt). |
| RNF-08 | Observabilidad | Se plantea usar Telemetry y logging en los puntos útiles para depurar. |
| RNF-09 | Mantenibilidad y calidad del desarrollo | El código deberá ser legible y coherente y las pruebas automatizadas cubrirán las partes que el equipo considere prioritarias. |

## 5. Arquitectura del software (cliente–servidor distribuido y C4)

EventPulse adopta el estilo cliente–servidor distribuido: la aplicación se organiza en servicios independientes que pueden repartirse entre varias máquinas o nodos, de modo que el fallo o la carga de una parte no arrastre necesariamente a todo el sistema. Los clientes son ligeros: solo hacen uso del sistema a través de la interfaz publicada; la lógica de negocio reside en el lado servidor.

Entre clientes y servicios suele interponerse un directorio, el cual publica la forma en que los clientes pueden invocar el sistema y redirige cada petición al servicio que corresponda, recogiendo después la respuesta hacia el cliente. Ese componente intermedio desacopla a los clientes del nodo concreto donde corre cada servicio, a cambio de ser un punto que hay que dimensionar bien para que no limite el rendimiento.

En el interior de cada servidor (N1, N2, …, Nm) conviven uno o más servicios que reciben el trabajo encaminado por el directorio, lo procesan y devuelven el resultado siguiendo el mismo patrón de ida y vuelta a través del directorio. Las responsabilidades de EventPulse se reparten en los servicios nombrados en el diagrama de contenedores.

### 5.1 Vista de contexto

Caja negra del producto frente a los actores: qué aporta EventPulse al participante y al administrador, sin entrar en directorio ni nodos.

```mermaid
C4Context
  title EventPulse — Contexto

  Person(participant, "Participante", "Usuario registrado: participa en eventos en directo, chat y votaciones")
  Person(admin, "Administrador", "Gestiona el catálogo de eventos y su ciclo de vida")

  System(ep, "EventPulse", "Sistema software que da soporte a eventos en vivo, comunicación en tiempo real, votaciones y resultado con las votaciones y el Social Feeling tras el cierre.")

  Rel(participant, ep, "Usa el sistema", "Consultas, participación en salas y votos")
  Rel(admin, ep, "Usa el sistema", "Alta, modificación y control de eventos")
```

### 5.2 Vista de contenedores

Lectura del diagrama: arriba, los clientes y el directorio; en el medio, dos nodos de aplicación típicos (N1 y N2) con los mismos roles; abajo, el nodo de escala Nm y, en un contenedor aparte, la base de datos compartida: el almacén es único para todo el sistema. El servicio de cierre no pasa por el directorio: se dispara al finalizar un evento, y escribe en la base de datos junto al evento.

```mermaid
C4Container
  title EventPulse — Vista de contenedores

  Person(participant, "Participante", "Cliente")
  Person(admin, "Administrador", "Cliente")

  System_Boundary(sistema, "EventPulse") {
    Container(directorio, "Directorio", "Entrada única", "Publica la interfaz hacia los clientes; redirige peticiones y devuelve respuestas.")

    Container_Boundary(servidor_n1, "Servidor N1") {
      Container(n1_svc_cuentas, "Cuentas y acceso", "Servicio", "Registro e identidad.")
      Container(n1_svc_eventos, "Eventos y catálogo", "Servicio", "CRUD, estados y consultas.")
      Container(n1_svc_salas, "Salas en vivo", "Servicio", "Chat y buffer de contexto.")
      Container(n1_svc_votos, "Votaciones en directo", "Servicio", "Preguntas, votos y parciales.")
      Container(n1_svc_cierre, "Cierre (interno)", "Proceso", "Sin API pública: orquesta fin de sala/voto y escribe resultados.")
    }

    Container_Boundary(servidor_n2, "Servidor N2") {
      Container(n2_svc_cuentas, "Cuentas y acceso", "Servicio", "Homólogo de N1.")
      Container(n2_svc_eventos, "Eventos y catálogo", "Servicio", "Homólogo de N1.")
      Container(n2_svc_salas, "Salas en vivo", "Servicio", "Homólogo de N1.")
      Container(n2_svc_votos, "Votaciones en directo", "Servicio", "Homólogo de N1.")
      Container(n2_svc_cierre, "Cierre (interno)", "Proceso", "Homólogo de N1.")
    }

    Container_Boundary(servidor_nm, "Servidor Nm") {
      Container(nm_svc_replica, "Réplica de servicios", "Servicio", "Mismos cuatro roles vía directorio + cierre interno; escala horizontal.")
    }

    Container_Boundary(contenedor_bd, "Almacén compartido") {
      ContainerDb(db, "Base de datos", "Persistencia compartida", "Usuarios y datos de cuenta; eventos y estados; votos; Social Feeling e historial por evento; lecturas para catálogo y detalle.")
    }
  }

  Rel(participant, directorio, "Petición", "")
  Rel(directorio, participant, "Respuesta", "")

  Rel(admin, directorio, "Petición", "")
  Rel(directorio, admin, "Respuesta", "")

  Rel(directorio, n1_svc_cuentas, "Redirige", "")
  Rel(n1_svc_cuentas, directorio, "Responde", "")
  Rel(directorio, n1_svc_eventos, "Redirige", "")
  Rel(n1_svc_eventos, directorio, "Responde", "")
  Rel(directorio, n1_svc_salas, "Redirige", "")
  Rel(n1_svc_salas, directorio, "Responde", "")
  Rel(directorio, n1_svc_votos, "Redirige", "")
  Rel(n1_svc_votos, directorio, "Responde", "")

  Rel(directorio, n2_svc_cuentas, "Redirige", "")
  Rel(n2_svc_cuentas, directorio, "Responde", "")
  Rel(directorio, n2_svc_eventos, "Redirige", "")
  Rel(n2_svc_eventos, directorio, "Responde", "")
  Rel(directorio, n2_svc_salas, "Redirige", "")
  Rel(n2_svc_salas, directorio, "Responde", "")
  Rel(directorio, n2_svc_votos, "Redirige", "")
  Rel(n2_svc_votos, directorio, "Responde", "")

  Rel(directorio, nm_svc_replica, "Redirige", "")
  Rel(nm_svc_replica, directorio, "Responde", "")

  Rel(n1_svc_cuentas, db, "Lee / escribe", "Usuarios")
  Rel(n1_svc_eventos, db, "Lee / escribe", "Eventos")
  Rel(n1_svc_votos, db, "Lee / escribe", "Votos")
  Rel(n1_svc_salas, db, "Opcional", "Traza de sala")

  Rel(n2_svc_cuentas, db, "Lee / escribe", "")
  Rel(n2_svc_eventos, db, "Lee / escribe", "")
  Rel(n2_svc_votos, db, "Lee / escribe", "")
  Rel(n2_svc_salas, db, "Opcional", "")

  Rel(nm_svc_replica, db, "Lee / escribe", "Misma persistencia")

  Rel(n1_svc_eventos, n1_svc_cierre, "Finalizado")
  Rel(n1_svc_votos, n1_svc_cierre, "Contexto")
  Rel(n1_svc_cierre, n1_svc_salas, "Orden")
  Rel(n1_svc_cierre, db, "Lee / escribe")

  Rel(n2_svc_eventos, n2_svc_cierre, "Finalizado", "")
  Rel(n2_svc_votos, n2_svc_cierre, "Contexto", "")
  Rel(n2_svc_cierre, n2_svc_salas, "Orden", "")
  Rel(n2_svc_cierre, db, "Lee / escribe", "")
```

