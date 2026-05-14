
## 🐳 Guía de Despliegue con Docker

Esta aplicación está optimizada para ejecutarse en entornos de contenedores. El flujo de trabajo se basa en la construcción de una imagen base y la orquestación mediante **Docker Compose** para facilitar el descubrimiento de nodos vía DNS.

### 🛠 Requisitos Previos

* **Docker** instalado (v20.10+).
* **Docker Compose** (v2.0+).

---

### 🚀 Pasos para el Despliegue

#### 1. Construcción de la Imagen

Primero, sitúate en el directorio raíz del proyecto y genera la imagen local:

```bash
cd event_pulse
docker build -t event_pulse_app .

```

#### 2. Ejecución y Escalado

Para levantar la infraestructura, utilizamos `docker-compose`. Si necesitas alta disponibilidad o probar el balanceo de carga, puedes escalar los nodos fácilmente.

Para arrancar el servicio con **dos nodos en paralelo**, ejecuta:

```bash
docker compose up --build --scale app=2

```

---

### 🌐 Arquitectura y Red

El sistema utiliza el **servidor DNS interno de Docker** para el descubrimiento de servicios. Esto permite que:

* **Interconectividad:** Los nodos se reconozcan entre sí mediante su nombre de servicio.
* **Balanceo:** Docker Compose gestione las peticiones entre las instancias escaladas de forma automática.

> [!TIP]
> Si realizas cambios en el código fuente, asegúrate de usar el flag `--build` al levantar el compose para refrescar la imagen con los últimos cambios.
