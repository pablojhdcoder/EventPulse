Este documento explica cómo funciona la infraestructura de `EventPulse` en términos simples. Vamos a ver cómo se forman los nodos, qué hace OTP en la aplicación y qué podemos monitorear para saber si todo está bien.

## 1. ¿Qué es OTP y por qué importa?

OTP es la base del sistema. En `EventPulse`, usamos OTP para manejar procesos con supervisores y para hacer que la aplicación sea estable.

- Cada parte importante corre dentro de un supervisor.
- Si un proceso falla, el supervisor lo reinicia.
- Esto nos da una aplicación más confiable sin tener que escribir manejo de errores complicado.

En `EventPulse` hay supervisores para:

- la web y los endpoints de Phoenix
- los chats en tiempo real
- el manejo de votos
- las tareas asíncronas que guardan datos en la base

## 2. Clúster: cómo se comunican varios nodos

El clúster se arma con `dns_cluster`, que es el componente encargado de encontrar otros nodos dentro de la misma red.

- Cuando está configurado, el nodo busca otros nodos usando DNS.
- Si no se configura, el nodo arranca solo.
- Para que funcione, todos los nodos deben compartir el mismo `ERL_COOKIE`.

### ¿Qué pasa dentro del clúster?

- Todos los nodos pueden enviar mensajes entre sí.
- El servicio usa `Phoenix.PubSub` para transmitir eventos y mensajes.
- El proceso `EventPulse.Votes.VoteAggregator` se registra como un solo proceso global usando `:global`.

Esto significa que, aunque haya varios nodos, el contador de votos funciona como si fuera uno solo.

## 3. Qué observamos y por qué

Observabilidad es ver qué está pasando. En `EventPulse` observamos principalmente tres cosas:

- métricas
- logs
- estado de los procesos

### Métricas principales

Recogemos información útil sobre:

- cuántas peticiones entran a Phoenix
- cuánto tarda cada endpoint
- cuánto tarda la base de datos
- cuánta memoria usa la aplicación
- cuántos votos se generan y se guardan
- cuántos mensajes llegan a los chats

Estas métricas nos ayudan a detectar problemas antes de que afecten a los usuarios.

### Logs

Los logs están pensados para ser legibles y útiles:

- incluyen fecha y hora
- muestran el nivel de gravedad (`info`, `error`, etc.)
- traen datos de contexto como `request_id`, módulo y función

Cuando usamos logs estructurados, se vuelve más fácil buscar errores y ver qué pasó.

### Diagnóstico en desarrollo

En desarrollo, podemos ver un panel con datos de la aplicación en vivo usando LiveDashboard.

- Disponible en `/dev/dashboard`
- Muestra estadísticas básicas de la app
- Nos ayuda a entender cómo se comporta el sistema mientras probamos

## 4. Cómo desplegar con Docker

La aplicación está lista para correr en Docker. La idea es sencilla:

1. construir la imagen
2. arrancar el servicio
3. usar DNS para que los nodos se descubran entre sí

### Pasos básicos

```bash
cd event_pulse
docker build -t event_pulse_app .
```

Luego, para usar dos nodos en paralelo:

```bash
docker compose up --build --scale app=2
```

### Variables importantes

- `PHX_SERVER=true` para que Phoenix arranque el servidor web
- `DATABASE_URL` para conectar a PostgreSQL
- `SECRET_KEY_BASE` en producción debe ser seguro
- `DNS_CLUSTER_QUERY=app` para activar el descubrimiento de nodos
- `ERL_COOKIE=event_pulse_cookie` para que los nodos se puedan ver entre sí

## 5. Cómo funciona el flujo de votos y chat

### Votos

Cuando llega un voto:

- se procesa en memoria
- se cuenta en un único agregador global
- luego se guarda en la base de datos de forma asíncrona

Este enfoque ayuda a que la aplicación responda rápido y mantenga una vista consistente del total de votos.

### Chat

Las salas de chat funcionan como procesos supervisados.

- cada sala está registrada y protegida por supervisores
- si una sala falla, se reinicia sola
- el sistema mantiene mensajes recientes en memoria para eficiencia

## 6. Operación diaria simple

Para cuidar la infraestructura, hay que verificar algunos puntos:

- que PostgreSQL esté funcionando
- que los nodos formen clúster correctamente
- que no haya errores graves en los logs
- que las métricas no muestren consumos inusuales

Si ves que los nodos no se descubren entre sí, revisa `DNS_CLUSTER_QUERY` y `ERL_COOKIE`.

## 7. Por qué esta infraestructura es una buena base

Esta configuración es sencilla pero potente:

- OTP da estabilidad gracias a los supervisores
- el clúster permite escalar con más nodos
- la observabilidad nos ayuda a detectar problemas temprano

Además, la arquitectura está preparada para crecer. Si en el futuro se quiere distribuir más trabajo o sincronizar procesos de forma más sólida, podemos agregar herramientas como `Horde` o `libcluster` sin rehacer todo.