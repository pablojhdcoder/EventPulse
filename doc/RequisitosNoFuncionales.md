# EventPulse
Plataforma de eventos en vivo con votaciones y chat entre espectadores.

## Requisitos no funcionales

### Rendimiento
- RNF-01: Mensajes y votos en tiempo real con baja latencia.

### Seguridad
- RNF-02: Solo usuarios autenticados acceden al sistema.

### Disponibilidad
- RNF-03: El sistema sigue funcionando aunque un proceso falle. 

### Escalabilidad
- RNF-04: Miles de conexiones simultáneas sin degradar el rendimiento.

### Tolerancia a fallos
- RNF-05: Fallo en un proceso aislado no arrastra al resto del sistema.

### Consistencia
- RNF-06: Cada usuario solo emite un solo voto por pregunta.

### Mantenibilidad
- RNF-07: Código legible y cubierto por pruebas automatizadas.

### Observabilidad
- RNF-08: Métricas y logs para detectar problemas en producción. 

### Escalabilidad horizontal
- RNF-09: Arquitectura crece añadiendo más nodos sin rediseñar el sistema.

